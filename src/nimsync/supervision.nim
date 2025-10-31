## nimsync — Enhanced Supervision Trees & Fault Tolerance
##
## This module implements Erlang-style supervision trees with advanced fault
## tolerance patterns, adapted for Nim and the actor model.
##
## Key Features:
## - Hierarchical supervision with configurable policies
## - Automatic actor restart with exponential backoff
## - Cascade failure prevention
## - DeathWatch for lifecycle events
## - Bulkhead isolation and circuit breaker patterns

import std/[atomics, times, tables, sequtils, options]
import ./errors

type
  ## Supervision strategy for child actor failures
  SupervisionStrategy* = enum
    OneForOne        ## Restart only failed child
    OneForAll        ## Restart failed + all siblings
    RestForOne       ## Restart failed + younger siblings
    Escalate         ## Escalate to parent supervisor

  ## Failure handling action
  FailureAction* = enum
    Restart          ## Restart the actor
    Resume           ## Resume processing
    Terminate        ## Terminate the actor
    Escalate         ## Escalate to supervisor

  ## Failure statistics for a supervised actor
  FailureStats* = object
    totalFailures*: Atomic[uint32]
    recentFailures*: Atomic[uint32]
    lastFailureTime*: Atomic[int64]
    consecutiveFailures*: Atomic[uint32]
    totalRestarts*: Atomic[uint32]

  ## Restart policy with thresholds and windows
  RestartPolicy* = object
    ## Maximum failures allowed in window
    maxFailures*: uint32
    ## Time window for counting failures (seconds)
    windowSeconds*: int
    ## Strategy when threshold exceeded
    strategy*: FailureAction
    ## Initial restart delay (milliseconds)
    initialDelayMs*: int
    ## Maximum restart delay (milliseconds)
    maxDelayMs*: int
    ## Backoff multiplier (exponential backoff)
    backoffMultiplier*: float

  ## Supervision configuration
  SupervisionConfig* = object
    ## Strategy for handling failures
    strategy*: SupervisionStrategy
    ## Restart policy
    restartPolicy*: RestartPolicy
    ## Enable bulkhead isolation
    bulkhead*: bool
    ## Bulkhead pool size
    bulkheadPoolSize*: int
    ## DeathWatch enabled
    deathWatch*: bool

  ## Supervisor node in the hierarchy
  SupervisorNode* = ref object
    ## Unique supervisor ID
    id*: string
    ## Parent supervisor
    parent*: Option[SupervisorNode]
    ## Child supervisors
    children*: Table[string, SupervisorNode]
    ## Supervised actors
    actors*: Table[string, FailureStats]
    ## Supervision configuration
    config*: SupervisionConfig
    ## Failure history
    failureHistory*: seq[int64]
    ## Active actors count
    activeActorsCount*: Atomic[int]

  ## DeathWatch event
  DeathWatchEvent* = object
    actorId*: string
    reason*: string
    timestamp*: int64
    failureStats*: FailureStats

  ## Circuit breaker state
  CircuitBreakerState* = enum
    Closed          ## Normal operation
    Open            ## Rejecting requests
    HalfOpen        ## Testing if recovered

  ## Circuit breaker pattern
  CircuitBreaker* = ref object
    ## Current state
    state*: Atomic[CircuitBreakerState]
    ## Failure count
    failureCount*: Atomic[int]
    ## Success count
    successCount*: Atomic[int]
    ## Failure threshold
    failureThreshold*: int
    ## Success threshold to close
    successThreshold*: int
    ## Timeout before HalfOpen
    timeoutNs*: int64
    ## Last state change time
    lastStateChangeTime*: Atomic[int64]

  ## Bulkhead isolation
  Bulkhead* = ref object
    ## Thread pool size
    poolSize*: int
    ## Current active tasks
    activeTasks*: Atomic[int]
    ## Maximum concurrent tasks
    maxConcurrent*: int
    ## Queue of pending tasks
    pendingTasks*: Atomic[int]

## Create default restart policy
proc defaultRestartPolicy*(): RestartPolicy =
  RestartPolicy(
    maxFailures: 3,
    windowSeconds: 10,
    strategy: Terminate,
    initialDelayMs: 100,
    maxDelayMs: 30000,
    backoffMultiplier: 2.0
  )

## Create default supervision config
proc defaultSupervi sionConfig*(): SupervisionConfig =
  SupervisionConfig(
    strategy: OneForOne,
    restartPolicy: defaultRestartPolicy(),
    bulkhead: false,
    bulkheadPoolSize: 10,
    deathWatch: true
  )

## Create a new supervisor node
proc newSupervisor*(id: string, config: SupervisionConfig = defaultSupervisionConfig()): SupervisorNode =
  SupervisorNode(
    id: id,
    parent: none(SupervisorNode),
    children: initTable[string, SupervisorNode](),
    actors: initTable[string, FailureStats](),
    config: config,
    failureHistory: @[],
    activeActorsCount: 0
  )

## Register an actor under supervision
proc registerActor*(supervisor: SupervisorNode, actorId: string) =
  if actorId notin supervisor.actors:
    supervisor.actors[actorId] = FailureStats(
      totalFailures: 0'u32,
      recentFailures: 0'u32,
      lastFailureTime: 0'i64,
      consecutiveFailures: 0'u32,
      totalRestarts: 0'u32
    )
    discard atomicInc(supervisor.activeActorsCount)

## Unregister an actor
proc unregisterActor*(supervisor: SupervisorNode, actorId: string) =
  if actorId in supervisor.actors:
    supervisor.actors.del(actorId)
    discard atomicDec(supervisor.activeActorsCount)

## Record a failure for an actor
proc recordFailure*(supervisor: SupervisorNode, actorId: string): bool =
  if actorId notin supervisor.actors:
    return false

  let stats = supervisor.actors[actorId]
  let now = getTime().toUnixNanos()

  discard atomicInc(stats.totalFailures)
  discard atomicInc(stats.recentFailures)
  discard atomicInc(stats.consecutiveFailures)
  atomicStore(stats.lastFailureTime, now)

  supervisor.failureHistory.add(now)

  # Check against restart policy
  let policy = supervisor.config.restartPolicy
  let windowNs = policy.windowSeconds.int64 * 1_000_000_000

  # Count failures in window
  let recentFailures = supervisor.failureHistory.filterIt(it > now - windowNs)

  if recentFailures.len.uint32 > policy.maxFailures:
    return false  # Threshold exceeded

  true

## Calculate exponential backoff delay
proc calculateBackoffDelay*(supervisor: SupervisorNode, restartCount: uint32): int =
  let policy = supervisor.config.restartPolicy
  let delayMs = float(policy.initialDelayMs) * pow(policy.backoffMultiplier, float(restartCount))
  let clamped = min(delayMs, float(policy.maxDelayMs))
  int(clamped)

## Get failure statistics
proc getFailureStats*(supervisor: SupervisorNode, actorId: string): Option[FailureStats] =
  if actorId in supervisor.actors:
    some(supervisor.actors[actorId])
  else:
    none(FailureStats)

## Get active actor count
proc getActiveActorCount*(supervisor: SupervisorNode): int =
  atomicLoad(supervisor.activeActorsCount)

## Create circuit breaker
proc newCircuitBreaker*(failureThreshold: int = 5,
                        successThreshold: int = 2,
                        timeoutMs: int = 60000): CircuitBreaker =
  CircuitBreaker(
    state: Closed,
    failureCount: 0,
    successCount: 0,
    failureThreshold: failureThreshold,
    successThreshold: successThreshold,
    timeoutNs: timeoutMs.int64 * 1_000_000,
    lastStateChangeTime: getTime(.toUnixNanos())
  )

## Check if circuit breaker allows call
proc isCallAllowed*(breaker: CircuitBreaker): bool =
  let state = atomicLoad(breaker.state)

  case state:
  of Closed:
    true
  of Open:
    # Check if timeout expired
    let now = getTime().toUnixNanos()
    let lastChange = atomicLoad(breaker.lastStateChangeTime)
    if now - lastChange > breaker.timeoutNs:
      # Transition to HalfOpen
      atomicStore(breaker.state, HalfOpen)
      atomicStore(breaker.successCount, 0)
      true
    else:
      false
  of HalfOpen:
    true

## Record success
proc recordSuccess*(breaker: CircuitBreaker) =
  let state = atomicLoad(breaker.state)

  case state:
  of Closed:
    atomicStore(breaker.failureCount, 0)
  of HalfOpen:
    let count = atomicInc(breaker.successCount)
    if count >= breaker.successThreshold:
      # Transition to Closed
      atomicStore(breaker.state, Closed)
      atomicStore(breaker.failureCount, 0)
  else:
    discard

## Record failure
proc recordFailure*(breaker: CircuitBreaker) =
  let state = atomicLoad(breaker.state)

  case state:
  of Closed:
    let count = atomicInc(breaker.failureCount)
    if count >= breaker.failureThreshold:
      # Transition to Open
      atomicStore(breaker.state, Open)
      atomicStore(breaker.lastStateChangeTime, getTime().toUnixNanos())
  of HalfOpen:
    # Back to Open
    atomicStore(breaker.state, Open)
    atomicStore(breaker.lastStateChangeTime, getTime().toUnixNanos())
  else:
    discard

## Create bulkhead
proc newBulkhead*(poolSize: int = 10, maxConcurrent: int = 5): Bulkhead =
  Bulkhead(
    poolSize: poolSize,
    activeTasks: 0,
    maxConcurrent: maxConcurrent,
    pendingTasks: 0
  )

## Check if task can be admitted
proc canAdmitTask*(bulkhead: Bulkhead): bool =
  let active = atomicLoad(bulkhead.activeTasks)
  active < bulkhead.maxConcurrent

## Record task start
proc recordTaskStart*(bulkhead: Bulkhead) =
  discard atomicInc(bulkhead.activeTasks)

## Record task end
proc recordTaskEnd*(bulkhead: Bulkhead) =
  let active = atomicLoad(bulkhead.activeTasks)
  if active > 0:
    discard atomicDec(bulkhead.activeTasks)

## Get bulkhead utilization
proc getUtilization*(bulkhead: Bulkhead): float =
  let active = atomicLoad(bulkhead.activeTasks)
  float(active) / float(bulkhead.maxConcurrent)

## Format supervisor statistics
proc formatStats*(supervisor: SupervisorNode): string =
  var output = "SupervisorNode(" & supervisor.id & ")\n"
  output &= "  Active Actors: " & $getActiveActorCount(supervisor) & "\n"
  output &= "  Failure History: " & $supervisor.failureHistory.len & " events\n"

  for actorId, stats in supervisor.actors:
    output &= "  Actor: " & actorId & "\n"
    output &= "    Total Failures: " & $atomicLoad(stats.totalFailures) & "\n"
    output &= "    Total Restarts: " & $atomicLoad(stats.totalRestarts) & "\n"

  output
