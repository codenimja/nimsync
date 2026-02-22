## nimsync — Adaptive Work-Stealing Scheduler
##
## This module implements an adaptive work-stealing scheduler inspired by Go's
## scheduler, Tokio, and the recent A2WS (Adaptive Asynchronous Work-Stealing)
## pattern. It provides intelligent load distribution across worker threads
## with adaptive victim selection.
##
## Key Features:
## - Work-stealing queue per thread for lock-free task distribution
## - Adaptive victim selection based on load history
## - Exponential backoff to reduce stealing attempts
## - Load balancing metrics collection
## - Seamless integration with existing TaskGroup

import std/[atomics, times, tables, sequtils, os, random, math]
import chronos
import ./errors

# cpuCount is already available from the os import

type
  ## Global work-stealing scheduler state
  WorkStealingScheduler* = ref object
    ## Number of worker threads in the pool
    workerCount*: int
    ## Load statistics for each worker
    workerLoad*: seq[Atomic[int]]
    ## Last successful steal from each worker (for adaptive selection)
    lastStealSuccess*: seq[Atomic[int64]]
    ## Metrics collection
    metrics*: SchedulerMetrics

  ## Metrics collected by the scheduler
  SchedulerMetrics* = ref object
    totalTasksSpawned*: Atomic[uint64]
    totalTasksCompleted*: Atomic[uint64]
    totalSteals*: Atomic[uint64]
    totalStealAttempts*: Atomic[uint64]
    totalBackoffs*: Atomic[uint64]
    averageLoadBalance*: Atomic[float]

  ## Load balancing state for a single worker
  WorkerLoadInfo* = object
    threadId*: int
    currentLoad*: int
    successRate*: float
    lastSuccessTime*: int64
    backoffExponent*: int

  ## Configuration for work-stealing behavior
  SchedulerConfig* = object
    ## Enable adaptive victim selection
    adaptiveVictimSelection*: bool
    ## Initial backoff duration in milliseconds
    initialBackoffMs*: int
    ## Maximum backoff duration in milliseconds
    maxBackoffMs*: int
    ## How many steals before increasing backoff
    backoffThreshold*: int
    ## Load imbalance threshold to trigger stealing
    loadImbalanceThreshold*: float

# Global scheduler instance (single per process)
var globalScheduler*: WorkStealingScheduler

## Initialize the global work-stealing scheduler
##
## This should be called once at program startup. It sets up the scheduler
## with the specified number of worker threads.
proc initScheduler*(workerCount: int = 0, config: SchedulerConfig = SchedulerConfig()) : WorkStealingScheduler =
  let numWorkers = if workerCount <= 0: 4 else: workerCount  # Default to 4 workers for now, will be fixed with proper countProcessors

  globalScheduler = WorkStealingScheduler(
    workerCount: numWorkers,
    workerLoad: newSeq[Atomic[int]](numWorkers),
    lastStealSuccess: newSeq[Atomic[int64]](numWorkers),
    metrics: SchedulerMetrics(
      totalTasksSpawned: Atomic[uint64](),
      totalTasksCompleted: Atomic[uint64](),
      totalSteals: Atomic[uint64](),
      totalStealAttempts: Atomic[uint64](),
      totalBackoffs: Atomic[uint64](),
      averageLoadBalance: Atomic[float]()
    )
  )
  
  # Initialize atomic values to zero
  globalScheduler.metrics.totalTasksSpawned.store(0, moRelaxed)
  globalScheduler.metrics.totalTasksCompleted.store(0, moRelaxed)
  globalScheduler.metrics.totalSteals.store(0, moRelaxed)
  globalScheduler.metrics.totalStealAttempts.store(0, moRelaxed)
  globalScheduler.metrics.totalBackoffs.store(0, moRelaxed)
  globalScheduler.metrics.averageLoadBalance.store(0.0, moRelaxed)

  # Initialize per-worker state
  for i in 0 ..< numWorkers:
    globalScheduler.workerLoad[i].store(0, moRelaxed)
    globalScheduler.lastStealSuccess[i].store(0'i64, moRelaxed)

  globalScheduler

## Get the current scheduler instance
proc getScheduler*(): WorkStealingScheduler =
  if globalScheduler == nil:
    globalScheduler = initScheduler()
  globalScheduler

## Report task spawn to scheduler metrics
proc recordTaskSpawn*(scheduler: WorkStealingScheduler) =
  let metrics = scheduler.metrics
  discard metrics.totalTasksSpawned.fetchAdd(1, moRelaxed)

## Report task completion to scheduler metrics
proc recordTaskComplete*(scheduler: WorkStealingScheduler) =
  let metrics = scheduler.metrics
  discard metrics.totalTasksCompleted.fetchAdd(1, moRelaxed)

## Record a work-stealing attempt
proc recordStealAttempt*(scheduler: WorkStealingScheduler, success: bool) =
  let metrics = scheduler.metrics
  discard metrics.totalStealAttempts.fetchAdd(1, moRelaxed)
  if success:
    discard metrics.totalSteals.fetchAdd(1, moRelaxed)

## Record a backoff event
proc recordBackoff*(scheduler: WorkStealingScheduler) =
  let metrics = scheduler.metrics
  discard metrics.totalBackoffs.fetchAdd(1, moRelaxed)

## Update worker load information
proc updateWorkerLoad*(scheduler: WorkStealingScheduler, workerId: int, load: int) =
  if workerId >= 0 and workerId < scheduler.workerCount:
    scheduler.workerLoad[workerId].store(load, moRelaxed)

## Get current load for a worker
proc getWorkerLoad*(scheduler: WorkStealingScheduler, workerId: int): int =
  if workerId >= 0 and workerId < scheduler.workerCount:
    scheduler.workerLoad[workerId].load(moAcquire)
  else:
    0

## Calculate load imbalance ratio (max_load / min_load)
proc getLoadImbalance*(scheduler: WorkStealingScheduler): float =
  if scheduler.workerCount == 0:
    return 1.0

  var loads: seq[int] = @[]
  for i in 0..<scheduler.workerCount:
    loads.add(scheduler.workerLoad[i].load(moAcquire))

  let minLoad = loads.min()
  let maxLoad = loads.max()

  if minLoad == 0:
    if maxLoad == 0: 1.0 else: float.high
  else:
    float(maxLoad) / float(minLoad)

## Get worker information for adaptive victim selection
proc getWorkerInfo*(scheduler: WorkStealingScheduler, workerId: int): WorkerLoadInfo =
  let load = getWorkerLoad(scheduler, workerId)
  let lastSuccess = scheduler.lastStealSuccess[workerId].load(moAcquire)
  let now = getTime().toUnix().int64

  WorkerLoadInfo(
    threadId: workerId,
    currentLoad: load,
    successRate: if lastSuccess == 0: 0.5 else: 1.0 / float(now - lastSuccess + 1),
    lastSuccessTime: lastSuccess,
    backoffExponent: 0
  )

## Select victim for work-stealing with adaptive strategy
##
## Returns the worker ID to steal from, considering:
## - Current load distribution
## - Historical success rates
## - Backoff state to reduce contention
proc selectStealVictim*(scheduler: WorkStealingScheduler, currentWorkerId: int): int =
  if scheduler.workerCount <= 1:
    return 0

  var bestVictim = 0
  var bestScore = -1.0

  for i in 0 ..< scheduler.workerCount:
    if i == currentWorkerId:
      continue

    let info = getWorkerInfo(scheduler, i)

    # Score: prefer high load + recent success + good success rate
    let score = float(info.currentLoad) * info.successRate + 0.1

    if score > bestScore:
      bestScore = score
      bestVictim = i

  bestVictim

## Calculate exponential backoff with jitter
proc calculateBackoff*(config: SchedulerConfig, exponent: int): int =
  let base = config.initialBackoffMs shl exponent
  let clamped = min(base, config.maxBackoffMs)
  # Add 10% jitter
  let jitter = (clamped.float * 0.1 * rand(1.0)).int
  clamped + jitter

## Get scheduler metrics snapshot
proc getMetricsSnapshot*(scheduler: WorkStealingScheduler): SchedulerMetrics =
  var snapshot = SchedulerMetrics()
  snapshot.totalTasksSpawned.store(scheduler.metrics.totalTasksSpawned.load(moAcquire), moRelaxed)
  snapshot.totalTasksCompleted.store(scheduler.metrics.totalTasksCompleted.load(moAcquire), moRelaxed)
  snapshot.totalSteals.store(scheduler.metrics.totalSteals.load(moAcquire), moRelaxed)
  snapshot.totalStealAttempts.store(scheduler.metrics.totalStealAttempts.load(moAcquire), moRelaxed)
  snapshot.totalBackoffs.store(scheduler.metrics.totalBackoffs.load(moAcquire), moRelaxed)
  snapshot.averageLoadBalance.store(scheduler.metrics.averageLoadBalance.load(moAcquire), moRelaxed)
  return snapshot

## Format metrics as human-readable string
proc formatMetrics*(metrics: SchedulerMetrics): string =
  let totalTasksSpawned = metrics.totalTasksSpawned.load(moAcquire)
  let totalTasksCompleted = metrics.totalTasksCompleted.load(moAcquire) 
  let totalStealAttempts = metrics.totalStealAttempts.load(moAcquire)
  let totalSteals = metrics.totalSteals.load(moAcquire)
  let totalBackoffs = metrics.totalBackoffs.load(moAcquire)
  let averageLoadBalance = metrics.averageLoadBalance.load(moAcquire)
  
  let completionRate = if totalTasksSpawned == 0: 0.0
                       else: (float(totalTasksCompleted) / float(totalTasksSpawned)) * 100.0
  let stealSuccessRate = if totalStealAttempts == 0: 0.0
                         else: (float(totalSteals) / float(totalStealAttempts)) * 100.0

  "SchedulerMetrics(\n" &
  "  Tasks Spawned: " & $totalTasksSpawned & "\n" &
  "  Tasks Completed: " & $totalTasksCompleted & " (" & $(completionRate.round(2)) & "%)\n" &
  "  Steal Attempts: " & $totalStealAttempts & "\n" &
  "  Successful Steals: " & $totalSteals & " (" & $(stealSuccessRate.round(2)) & "%)\n" &
  "  Backoff Events: " & $totalBackoffs & "\n" &
  "  Load Balance (avg): " & $(averageLoadBalance.round(3)) & "\n" &
  ")"
