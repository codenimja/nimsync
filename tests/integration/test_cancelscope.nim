## CancelScope behavior test
##
## Tests cancellation scopes, timeouts, hierarchical cancellation, and shield protection

import std/[unittest, strutils, asyncdispatch]
import ../../src/nimsync

suite "CancelScope Behavior Tests":
  test "CancelScope creation and basic properties":
    var scope = initCancelScope()
    check scope.active
    check not scope.cancelled
    echo "✅ CancelScope creation works"

  test "Manual cancellation":
    try:
      var scope = initCancelScope()
      check scope.active
      check not scope.cancelled

      # Cancel the scope
      scope.cancel()
      check scope.cancelled
      check not scope.active
      echo "✅ Manual cancellation works"
    except Exception as e:
      echo "❌ Manual cancellation error: ", e.msg
      check false

  test "Timeout cancellation":
    try:
      var scope = initCancelScope()
      var taskCompleted = false

      proc longTask(): Future[void] {.async.} =
        await sleepAsync(500.milliseconds)  # Task that takes 500ms
        taskCompleted = true

      # Set a timeout of 100ms
      scope.setTimeout(100)

      # Start the task
      let taskFuture = longTask()

      # Wait a bit for timeout to trigger
      await sleepAsync(150.milliseconds)

      check scope.cancelled  # Should be cancelled due to timeout
      check not taskCompleted  # Task should not have completed
      echo "✅ Timeout cancellation works"
    except Exception as e:
      echo "❌ Timeout cancellation error: ", e.msg
      check false

  test "Hierarchical cancellation":
    try:
      var parentScope = initCancelScope()
      var childScope = initCancelScope()

      # Set up parent-child relationship
      childScope.setParent(parentScope)

      check parentScope.active
      check childScope.active

      # Cancel parent should cancel child
      parentScope.cancel()

      check parentScope.cancelled
      check childScope.cancelled
      echo "✅ Hierarchical cancellation works"
    except Exception as e:
      echo "❌ Hierarchical cancellation error: ", e.msg
      check false

  test "Cancellation token checking":
    try:
      var scope = initCancelScope()
      let token = scope.getToken()

      check not token.cancelled
      check token.active

      scope.cancel()

      check token.cancelled
      check not token.active
      echo "✅ Cancellation token checking works"
    except Exception as e:
      echo "❌ Cancellation token error: ", e.msg
      check false

  test "Shield protection":
    try:
      var outerScope = initCancelScope()
      var shieldedScope = initCancelScope()

      # Enable shield protection
      shieldedScope.setShielded(true)
      shieldedScope.setParent(outerScope)

      # Cancel outer scope
      outerScope.cancel()

      check outerScope.cancelled
      check not shieldedScope.cancelled  # Should be protected by shield
      echo "✅ Shield protection works"
    except Exception as e:
      echo "❌ Shield protection error: ", e.msg
      check false

echo "✅ CancelScope behavior tests completed"