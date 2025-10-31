## Async Test Framework for nimsync
##
## Modern E2E test framework optimized for async libraries with:
## - Chronos integration for true async testing
## - Performance measurement and validation
## - Memory leak detection
## - Flakiness reduction through smart waits
## - Structured test organization
## - CI/CD integration support

import std/[unittest, atomics, strformat, random, options, monotimes, os]
import std/times except Duration
import chronos
# import ./progress  # Removed to fix compilation issues

export unittest, times, monotimes, atomics, strformat, random, options, chronos
# export progress  # Removed to fix compilation issues

type
  TestMetrics* = object
    ## Performance metrics for test validation
    duration*: chronos.Duration
    memoryUsed*: int64
    operations*: int64
    throughput*: float64  # ops/second

  AsyncTestConfig* = object
    ## Configuration for async test execution
    timeout*: chronos.Duration
    maxMemory*: int64
    expectedThroughput*: float64
    retries*: int
    verbose*: bool

  TestResult* = object
    ## Comprehensive test result
    passed*: bool
    metrics*: TestMetrics
    errors*: seq[string]
    warnings*: seq[string]

# Global test configuration
var testConfig* = AsyncTestConfig(
  timeout: chronos.seconds(30),
  maxMemory: 100 * 1024 * 1024,  # 100MB
  expectedThroughput: 0.0,
  retries: 3,
  verbose: false
)

# Performance tracking
var globalMetrics* = (
  testsRun: Atomic[int](),
  testsPassed: Atomic[int](),
  testsFailed: Atomic[int](),
  totalDuration: Atomic[int64]()
)

# Progress bar utilities for test suites - REMOVED to fix compilation
# proc createTestProgress*(totalTests: int, prefix = "Running tests"): Progress =
#   ## Create a progress bar for test execution
#   Progress(
#     total: totalTests,
#     current: 0,
#     startTime: getTime(),
#     kind: pkBar,
#     width: 50,
#     label: prefix,
#     lastRender: ""
#   )

# proc createSuiteProgress*(totalSuites: int, prefix = "Test suites"): Progress =
#   ## Create a progress bar for test suite execution
#   Progress(
#     total: totalSuites,
#     current: 0,
#     startTime: getTime(),
#     kind: pkBar,
#     width: 40,
#     label: prefix,
#     lastRender: ""
#   )

# proc updateTestProgress*(progress: var Progress, completed: int, message = "") =
#   ## Update test progress bar
#   progress.update(completed)

# proc completeTestProgress*(progress: var Progress, message = "All tests completed! ✅") =
#   ## Complete test progress bar
#   progress.finish(true)

template asyncTest*(name: string, body: untyped): untyped =
  ## Async test wrapper with timeout and error handling
  test name:
    proc testProc(): Future[void] {.async.} =
      body

    try:
      waitFor testProc().wait(testConfig.timeout)
      discard globalMetrics.testsPassed.fetchAdd(1, moRelaxed)
    except AsyncTimeoutError:
      discard globalMetrics.testsFailed.fetchAdd(1, moRelaxed)
      fail("Test timed out after " & $testConfig.timeout)
    except CatchableError as e:
      discard globalMetrics.testsFailed.fetchAdd(1, moRelaxed)
      fail("Test failed: " & e.msg)
    finally:
      discard globalMetrics.testsRun.fetchAdd(1, moRelaxed)

template asyncTestWithMetrics*(name: string, expectedOps: int64, body: untyped): untyped =
  ## Async test with performance validation
  test name:
    proc testProc(): Future[TestResult] {.async.} =
      let startTime = Moment.now()
      let startMem = getOccupiedMem()
      var result = TestResult(passed: true)

      try:
        body

        let endTime = Moment.now()
        let endMem = getOccupiedMem()

        result.metrics = TestMetrics(
          duration: endTime - startTime,
          memoryUsed: endMem - startMem,
          operations: expectedOps,
          throughput: expectedOps.float64 * 1_000_000_000.0 / (endTime - startTime).nanoseconds.float64
        )

        # Validate performance expectations
        if testConfig.expectedThroughput > 0.0 and result.metrics.throughput < testConfig.expectedThroughput:
          result.warnings.add(fmt"Throughput {result.metrics.throughput:.0f} ops/sec below expected {testConfig.expectedThroughput:.0f}")

        if result.metrics.memoryUsed > testConfig.maxMemory:
          result.errors.add(fmt"Memory usage {result.metrics.memoryUsed} bytes exceeds limit {testConfig.maxMemory}")
          result.passed = false

      except CatchableError as e:
        result.passed = false
        result.errors.add(e.msg)

      return result

    let result = waitFor testProc().wait(testConfig.timeout)

    if testConfig.verbose:
      echo fmt"  Duration: {result.metrics.duration}"
      echo fmt"  Memory: {result.metrics.memoryUsed} bytes"
      if result.metrics.operations > 0:
        echo fmt"  Throughput: {result.metrics.throughput:.0f} ops/sec"

    for warning in result.warnings:
      echo fmt"  WARNING: {warning}"

    for error in result.errors:
      echo fmt"  ERROR: {error}"

    check result.passed

    if result.passed:
      discard globalMetrics.testsPassed.fetchAdd(1, moRelaxed)
    else:
      discard globalMetrics.testsFailed.fetchAdd(1, moRelaxed)

    discard globalMetrics.testsRun.fetchAdd(1, moRelaxed)
    discard globalMetrics.totalDuration.fetchAdd(result.metrics.duration.inNanoseconds, moRelaxed)

# proc eventually*(condition: proc(): bool, timeout: chronos.Duration = chronos.seconds(5),
#                 checkInterval: chronos.Duration = chronos.milliseconds(10)): Future[bool] {.async.} =
#   ## Wait for condition to become true with timeout
#   let deadline = Moment.now() + timeout

#   while Moment.now() < deadline:
#     try:
#       if condition():
#         return true
#     except Exception:
#       # Ignore exceptions in condition for test framework
#       discard
#     await sleepAsync(checkInterval)

#   return false

proc eventuallyAsync*(condition: proc(): Future[bool] {.async.}, timeout: chronos.Duration = chronos.seconds(5),
                     checkInterval: chronos.Duration = chronos.milliseconds(10)): Future[bool] {.async.} =
  ## Async version of eventually
  let deadline = Moment.now() + timeout

  while Moment.now() < deadline:
    if await condition():
      return true
    await sleepAsync(checkInterval)

  return false

proc withRetry*[T](operation: proc(): Future[T] {.async.}, maxRetries: int = 3,
                  delay: chronos.Duration = chronos.milliseconds(100)): Future[T] {.async.} =
  ## Retry operation with exponential backoff
  var attempt = 1
  var currentDelay = delay

  while attempt <= maxRetries:
    try:
      return await operation()
    except CatchableError as e:
      if attempt == maxRetries:
        raise e

      await sleepAsync(currentDelay)
      currentDelay = currentDelay * 2
      attempt += 1

proc withTimeout*[T](operation: proc(): Future[T] {.async.}, timeout: chronos.Duration): Future[T] {.async.} =
  ## Execute operation with timeout
  let timeoutFuture = sleepAsync(timeout)
  let operationFuture = operation()

  let completed = await race(operationFuture, timeoutFuture)

  if completed == timeoutFuture:
    operationFuture.cancel()
    raise newException(AsyncTimeoutError, fmt"Operation timed out after {timeout}")
  else:
    timeoutFuture.cancel()
    return operationFuture.read()

proc measureThroughput*[T](operation: proc(): Future[T] {.async.},
                          iterations: int): Future[float64] {.async.} =
  ## Measure throughput of repeated operations
  let startTime = Moment.now()

  for i in 0 ..< iterations:
    discard await operation()

  let endTime = Moment.now()
  let duration = endTime - startTime

  return iterations.float64 * 1_000_000_000.0 / duration.nanoseconds.float64

proc createTestData*[T](count: int, factory: proc(i: int): T): seq[T] =
  ## Create test data using factory function
  result = newSeqOfCap[T](count)
  for i in 0 ..< count:
    result.add(factory(i))

proc randomString*(length: int = 10): string =
  ## Generate random string for testing
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  result = newStringOfCap(length)
  for i in 0 ..< length:
    result.add(chars[rand(chars.len - 1)])

proc getTestStats*(): tuple[run: int, passed: int, failed: int, avgDuration: float64] =
  ## Get global test statistics
  let run = globalMetrics.testsRun.load(moAcquire)
  let passed = globalMetrics.testsPassed.load(moAcquire)
  let failed = globalMetrics.testsFailed.load(moAcquire)
  let totalDuration = globalMetrics.totalDuration.load(moAcquire)

  let avgDuration = if run > 0: totalDuration.float64 / run.float64 / 1_000_000.0 else: 0.0

  return (run: run, passed: passed, failed: failed, avgDuration: avgDuration)

# Test environment setup
proc setupTestEnvironment*() =
  ## Initialize test environment
  randomize()
  testConfig.verbose = getEnv("VERBOSE_TESTS") == "1"

proc teardownTestEnvironment*() =
  ## Cleanup test environment
  let stats = getTestStats()
  echo fmt"Test Summary: {stats.passed}/{stats.run} passed, {stats.failed} failed, avg {stats.avgDuration:.2f}ms"