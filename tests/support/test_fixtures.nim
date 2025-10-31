## Test Fixtures and Utilities
##
## Common test data, helpers, and fixtures for nimsync test suite

import std/[tables, random, times, sequtils, os, strutils]
import chronos
import ../../src/nimsync
import ./async_test_framework

export tables, random, times, sequtils, chronos, nimsync, async_test_framework

type
  # Test message types
  TestMessage* = object
    id*: int
    payload*: string
    timestamp*: MonoTime

  BenchmarkMessage* = object
    sequence*: int64
    data*: array[64, byte]  # Fixed size for consistent testing

  # Test actor states
  CounterState* = object
    count*: int
    messages*: seq[TestMessage]

  EchoState* = object
    lastMessage*: string

  AccumulatorState* = object
    total*: int64
    items*: seq[int]

# Test data generators
proc generateTestMessage*(id: int = -1): TestMessage =
  ## Generate a test message with optional ID
  TestMessage(
    id: if id >= 0: id else: rand(10000),
    payload: randomString(rand(10..100)),
    timestamp: getMonoTime()
  )

proc generateBenchmarkMessage*(sequence: int64): BenchmarkMessage =
  ## Generate a benchmark message with sequence number
  var msg = BenchmarkMessage(sequence: sequence)
  for i in 0 ..< msg.data.len:
    msg.data[i] = byte(rand(256))
  return msg

proc generateTestData*[T](count: int, generator: proc(): T): seq[T] =
  ## Generate sequence of test data
  result = newSeqOfCap[T](count)
  for i in 0 ..< count:
    result.add(generator())

# Performance test constants
const
  SMALL_TEST_SIZE* = 1_000
  MEDIUM_TEST_SIZE* = 10_000
  LARGE_TEST_SIZE* = 100_000
  STRESS_TEST_SIZE* = 1_000_000

  SMALL_BUFFER_SIZE* = 16
  MEDIUM_BUFFER_SIZE* = 1024
  LARGE_BUFFER_SIZE* = 16384

  SHORT_TIMEOUT* = 100.milliseconds
  MEDIUM_TIMEOUT* = 1.seconds
  LONG_TIMEOUT* = 10.seconds

# Expected performance targets
const
  TARGET_SPSC_THROUGHPUT* = 50_000_000.0  # 50M ops/sec
  TARGET_MPMC_THROUGHPUT* = 10_000_000.0  # 10M ops/sec
  TARGET_TASK_SPAWN_LATENCY* = 100.0      # 100ns
  TARGET_CANCEL_LATENCY* = 10.0           # 10ns
  TARGET_STREAM_THROUGHPUT* = 1_000_000.0 # 1M ops/sec

# Test helpers for channels
proc createTestChannel*[T](size: int, mode: ChannelMode): auto =
  ## Create a test channel with specified parameters
  return newChannel[T](size, mode)

proc fillChannel*[T](channel: var channels.Channel[T], items: openArray[T]): Future[void] {.async.} =
  ## Fill channel with test data
  for item in items:
    await channel.send(item)

proc drainChannel*[T](channel: var channels.Channel[T], maxItems: int = -1): Future[seq[T]] {.async.} =
  ## Drain all items from channel
  var items: seq[T] = @[]
  var count = 0

  while (maxItems < 0 or count < maxItems):
    try:
      let item = await channel.recv()
      items.add(item)
      count += 1
    except ChannelClosedError:
      break

  return items

# Test helpers for streams
proc createTestStream*[T](policy: streams.BackpressurePolicy, size: int = 1024): auto =
  ## Create a test stream with specified parameters
  return initStream[T](policy, size)

proc fillStream*[T](stream: var streams.Stream[T], items: openArray[T]): Future[void] {.async.} =
  ## Fill stream with test data
  for item in items:
    await stream.send(item)

proc drainStream*[T](stream: var streams.Stream[T], maxItems: int = -1): Future[seq[T]] {.async.} =
  ## Drain all items from stream
  var items: seq[T] = @[]
  var count = 0

  while (maxItems < 0 or count < maxItems):
    let item = await stream.receive()
    if item.isNone:
      break
    items.add(item.get())
    count += 1

  return items

# Test helpers for actors - COMMENTED OUT due to actors module issues
# proc createCounterActor*(system: var ActorSystem): auto =
#   ## Create a test counter actor
#   var behavior = initActorBehavior(CounterState(count: 0, messages: @[]))

#   behavior.handle(TestMessage, proc(state: var CounterState, msg: TestMessage) {.async.} =
#     state.count += 1
#     state.messages.add(msg)
#   )

#   return system.spawn(behavior)

# proc createEchoActor*(system: var ActorSystem): auto =
#   ## Create a test echo actor
#   var behavior = initActorBehavior(EchoState(lastMessage: ""))

#   behavior.handle(TestMessage, proc(state: var EchoState, msg: TestMessage) {.async.} =
#     state.lastMessage = msg.payload
#   )

#   return system.spawn(behavior)

# Load testing utilities
proc generateLoad*[T](duration: chronos.Duration, operation: proc(): Future[T] {.async.}): Future[int] {.async.} =
  ## Generate load for specified duration
  let deadline = getMonoTime() + duration
  var operations = 0

  while getMonoTime() < deadline:
    discard await operation()
    operations += 1

  return operations

proc parallelLoad*[T](workers: int, operation: proc(): Future[T] {.async.}): Future[seq[T]] {.async.} =
  ## Run operations in parallel with multiple workers
  var futures: seq[Future[T]] = @[]

  for i in 0 ..< workers:
    futures.add(operation())

  return await allFutures(futures)

# Memory testing utilities
proc withMemoryMonitoring*[T](operation: proc(): Future[T] {.async.}): Future[tuple[result: T, memoryUsed: int]] {.async.} =
  ## Execute operation with memory monitoring
  let startMem = getOccupiedMem()
  let result = await operation()
  let endMem = getOccupiedMem()

  return (result: result, memoryUsed: endMem - startMem)

# Error injection for testing
type
  ErrorInjector* = object
    failureRate*: float  # 0.0 to 1.0
    errors*: seq[ref CatchableError]

proc createErrorInjector*(failureRate: float): ErrorInjector =
  ## Create error injector with specified failure rate
  ErrorInjector(
    failureRate: failureRate,
    errors: @[
      (ref CatchableError)(newException(IOError, "Simulated IO error")),
      (ref CatchableError)(newException(IOError, "Simulated timeout")),
      (ref CatchableError)(newException(IOError, "Simulated resource exhaustion"))
    ]
  )

proc maybeInjectError*(injector: ErrorInjector) =
  ## Randomly inject error based on failure rate
  if rand(1.0) < injector.failureRate:
    let error = injector.errors[rand(injector.errors.len - 1)]
    raise error

# Test validation helpers
proc validateThroughput*(actualThroughput: float64, expectedThroughput: float64,
                        tolerance: float = 0.1): bool =
  ## Validate throughput is within tolerance of expected
  let minThroughput = expectedThroughput * (1.0 - tolerance)
  return actualThroughput >= minThroughput

proc validateLatency*(actualLatency: float64, expectedLatency: float64,
                     tolerance: float = 0.5): bool =
  ## Validate latency is within tolerance of expected
  let maxLatency = expectedLatency * (1.0 + tolerance)
  return actualLatency <= maxLatency

proc validateMemoryUsage*(actualMemory: int, maxMemory: int): bool =
  ## Validate memory usage is within limits
  return actualMemory <= maxMemory

# CI/CD integration helpers
proc shouldRunStressTests*(): bool =
  ## Check if stress tests should be run (e.g., in CI)
  return getEnv("RUN_STRESS_TESTS") == "1"

proc shouldRunPerformanceTests*(): bool =
  ## Check if performance tests should be run
  return getEnv("RUN_PERFORMANCE_TESTS") == "1"

proc getTestConcurrencyLevel*(): int =
  ## Get concurrency level for tests from environment
  let envLevel = getEnv("TEST_CONCURRENCY_LEVEL")
  if envLevel != "":
    try:
      return parseInt(envLevel)
    except ValueError:
      discard

  # Default based on CPU count
  when defined(windows):
    return 4
  else:
    return 8

# Test data cleanup
proc cleanupTestResources*() =
  ## Clean up any global test resources
  # Force GC to clean up any remaining objects
  when not defined(gcDestructors):
    GC_fullCollect()

# Test configuration based on environment
proc configureTestsForEnvironment*() =
  ## Configure tests based on runtime environment
  if getEnv("QUICK_TESTS") == "1":
    # Reduce test sizes for quick feedback
    testConfig.timeout = chronos.seconds(5)
  elif getEnv("CI") == "true":
    # CI environment adjustments
    testConfig.timeout = chronos.seconds(60)
    testConfig.verbose = true
  else:
    # Development environment
    testConfig.timeout = chronos.seconds(30)