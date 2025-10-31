## Unit Tests for Cancellation System
##
## Tests the high-performance hierarchical cancellation implementation

import std/[sequtils, atomics]
import ../../support/test_fixtures

suite "Cancellation System Unit Tests":

  setup:
    setupTestEnvironment()

  teardown:
    cleanupTestResources()

  asyncTest "Basic cancellation scope creation and usage":
    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      check not scope.cancelled
      check scope.active

      scope.cancel()

      check scope.cancelled
      check not scope.active
    )

  asyncTest "Cancellation check raises exception":
    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      scope.cancel()

      expect CancelledError:
        scope.checkCancelled()
    )

  asyncTest "Timeout cancellation":
    let startTime = getMonoTime()

    try:
      await withTimeout(100.milliseconds):
        await sleepAsync(200.milliseconds)  # Will timeout

      fail("Operation should have timed out")
    except CancelledError:
      let duration = getMonoTime() - startTime
      check duration >= 90.milliseconds  # Allow some tolerance
      check duration <= 150.milliseconds

  asyncTest "Timeout cancellation with successful completion":
    let result = await withTimeout(200.milliseconds):
      await sleepAsync(50.milliseconds)
      return "completed"

    check result == "completed"

  asyncTest "Deadline-based cancellation":
    let deadline = getMonoTime() + 100.milliseconds
    let startTime = getMonoTime()

    try:
      await withDeadline(deadline):
        await sleepAsync(200.milliseconds)  # Will exceed deadline

      fail("Operation should have exceeded deadline")
    except CancelledError:
      let duration = getMonoTime() - startTime
      check duration >= 90.milliseconds
      check duration <= 150.milliseconds

  asyncTest "Hierarchical cancellation - parent cancels children":
    var parentCancelled = false
    var childCancelled = false

    try:
      await withCancelScope(proc(parentScope: var CancelScope) {.async.} =
        await withCancelScope(proc(childScope: var CancelScope) {.async.} =
          # Cancel parent scope after short delay
          await sleepAsync(10.milliseconds)
          parentScope.cancel()

          # Check that parent cancellation propagates
          await sleepAsync(10.milliseconds)
          try:
            childScope.checkCancelled()
            fail("Child scope should have been cancelled")
          except CancelledError:
            childCancelled = true

          raise newException(CancelledError, "Child cancelled")
        )
      )
    except CancelledError:
      parentCancelled = true

    check parentCancelled
    check childCancelled

  asyncTest "Shield protects from parent cancellation":
    var parentCancelled = false
    var shieldedCompleted = false

    try:
      await withCancelScope(proc(parentScope: var CancelScope) {.async.} =
        # Cancel parent early
        parentScope.cancel()

        # Shielded operation should complete despite parent cancellation
        await shield:
          await sleepAsync(50.milliseconds)
          shieldedCompleted = true

        # But after shield, cancellation should be detected
        parentScope.checkCancelled()
      )
    except CancelledError:
      parentCancelled = true

    check parentCancelled
    check shieldedCompleted

  asyncTestWithMetrics "Cancellation check performance", TARGET_CANCEL_LATENCY.int64:
    const iterations = 1_000_000
    var scope = initCancelScope()

    let startTime = getMonoTime()

    for i in 0 ..< iterations:
      discard scope.cancelled  # Ultra-fast cancellation check

    let endTime = getMonoTime()
    let duration = endTime - startTime
    let avgLatency = duration.inNanoseconds.float64 / iterations.float64

    if testConfig.verbose:
      echo fmt"Cancellation check latency: {avgLatency:.2f} ns per check"

    check avgLatency < TARGET_CANCEL_LATENCY * 2  # Allow 2x tolerance

  asyncTest "Cancellation reasons are preserved":
    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      scope.cancel(CancelReason.Timeout)
      check scope.getReason() == CancelReason.Timeout
    )

    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      scope.cancel(CancelReason.Manual)
      check scope.getReason() == CancelReason.Manual
    )

  asyncTest "Cancellation tokens work correctly":
    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      let token = scope.getToken()

      check not token.cancelled

      scope.cancel()

      check token.cancelled

      expect CancelledError:
        token.checkCancelled()
    )

  asyncTest "Multiple nested scopes with different cancellation":
    var level1Cancelled = false
    var level2Cancelled = false
    var level3Completed = false

    try:
      await withCancelScope(proc(scope1: var CancelScope) {.async.} =
        await withCancelScope(proc(scope2: var CancelScope) {.async.} =
          await withCancelScope(proc(scope3: var CancelScope) {.async.} =
            # Cancel middle scope
            scope2.cancel()

            # Level 3 should be cancelled by level 2
            await sleepAsync(10.milliseconds)
            scope3.checkCancelled()
            level3Completed = true  # Should not reach here
          )
        )
      )
    except CancelledError:
      level2Cancelled = true

    check level2Cancelled
    check not level3Completed

  asyncTest "Cancellation scope cleanup on completion":
    var scopeCompleted = false

    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      await sleepAsync(10.milliseconds)
      scopeCompleted = true
      # Scope should complete normally without cancellation
    )

    check scopeCompleted

  asyncTest "Concurrent cancellation from multiple sources":
    let cancellationAttempts = Atomic[int]()
    var finalState = false

    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      # Multiple tasks trying to cancel the same scope
      var cancellers: seq[Future[void]] = @[]

      for i in 0 ..< 5:
        cancellers.add(proc() {.async.} =
          await sleepAsync((i * 2).milliseconds)
          scope.cancel()
          discard cancellationAttempts.fetchAdd(1, moRelaxed)
        )

      await allFutures(cancellers)

      # Should be cancelled by now
      expect CancelledError:
        scope.checkCancelled()
    )

    # All cancellation attempts should have been made
    check cancellationAttempts.load(moAcquire) == 5

  asyncTest "Cancellation with resource cleanup":
    var resourceAcquired = false
    var resourceReleased = false

    try:
      await withCancelScope(proc(scope: var CancelScope) {.async.} =
        resourceAcquired = true

        # Cancel scope after acquiring resource
        scope.cancel()

        try:
          # This should detect cancellation
          scope.checkCancelled()
        finally:
          resourceReleased = true
      )
    except CancelledError:
      # Expected
      discard

    check resourceAcquired
    check resourceReleased

  asyncTest "Timeout accuracy":
    const timeoutDuration = 100.milliseconds
    const tolerance = 20.milliseconds

    let measurements = newSeq[Duration](5)

    for i in 0 ..< 5:
      let startTime = getMonoTime()

      try:
        await withTimeout(timeoutDuration):
          await sleepAsync(timeoutDuration * 2)
        fail("Should have timed out")
      except CancelledError:
        measurements[i] = getMonoTime() - startTime

    # Check that most timeouts are within tolerance
    var accurateTimeouts = 0
    for duration in measurements:
      if duration >= (timeoutDuration - tolerance) and
         duration <= (timeoutDuration + tolerance):
        accurateTimeouts += 1

    check accurateTimeouts >= 3  # At least 3 out of 5 should be accurate

  asyncTest "Cancellation state transitions":
    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      # Initially active
      check scope.active
      check not scope.cancelled
      check not scope.completed

      # Cancel the scope
      scope.cancel()

      check not scope.active
      check scope.cancelled
      check not scope.completed
    )

  asyncTest "Cancellation with current scope helpers":
    var detectedCancellation = false

    try:
      await withCancelScope(proc(scope: var CancelScope) {.async.} =
        scope.cancel()

        # Use global cancellation check
        checkCurrentCancellation()
      )
    except CancelledError:
      detectedCancellation = true

    check detectedCancellation

  asyncTest "Batch cancellation checking":
    const scopeCount = 10
    var scopes: seq[CancelScope] = @[]

    # Create multiple scopes
    for i in 0 ..< scopeCount:
      scopes.add(initCancelScope())

    # Cancel some of them
    for i in 0 ..< scopeCount div 2:
      scopes[i].cancel()

    # Batch check - should detect cancellation
    expect CancelledError:
      checkCancellation(scopes)

  when defined(debug):
    asyncTest "Debug information in cancellation":
      await withCancelScope(proc(scope: var CancelScope) {.async.} =
        scope.setName("test-scope")
        check scope.getName() == "test-scope"

        let stackTrace = scope.getStackTrace()
        check stackTrace.len > 0
      )

  when defined(statistics):
    asyncTest "Cancellation statistics collection":
      let initialStats = getScopeStats()

      await withCancelScope(proc(scope: var CancelScope) {.async.} =
        scope.cancel()

        try:
          scope.checkCancelled()
        except CancelledError:
          discard
      )

      let finalStats = getScopeStats()
      check finalStats.activeScopes >= initialStats.activeScopes