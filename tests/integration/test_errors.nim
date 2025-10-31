## Error handling and edge case tests
##
## Tests error propagation, resource limits, concurrent access, and edge cases

import std/[unittest, strutils, asyncdispatch]
import ../../src/nimsync

suite "Error Handling Tests":
  test "TaskGroup error propagation":
    try:
      var group = initTaskGroup(TaskPolicy.FailFast)
      var errorCaught = false

      proc failingTask(): Future[void] {.async.} =
        await sleepAsync(10.milliseconds)
        raise newException(ValueError, "Task failed")

      proc normalTask(): Future[void] {.async.} =
        await sleepAsync(100.milliseconds)

      discard group.spawn(failingTask)
      discard group.spawn(normalTask)

      try:
        await group.join()
      except ValueError:
        errorCaught = true

      check errorCaught
      echo "✅ TaskGroup error propagation works"
    except Exception as e:
      echo "❌ Error propagation test error: ", e.msg
      check false

  test "CancelScope timeout error":
    try:
      var scope = initCancelScope()
      var timeoutOccurred = false

      proc slowTask(): Future[void] {.async.} =
        await sleepAsync(200.milliseconds)

      scope.setTimeout(50)  # 50ms timeout

      try:
        await scope.run(slowTask)
      except TimeoutError:
        timeoutOccurred = true

      check timeoutOccurred
      check scope.cancelled
      echo "✅ CancelScope timeout error works"
    except Exception as e:
      echo "❌ Timeout error test error: ", e.msg
      check false

  test "Channel closed error":
    try:
      let chan = newChannel[int](5, ChannelMode.SPSC)
      var closedError = false

      # Close the channel
      chan.close()

      try:
        await chan.send(42)
      except ChannelClosedError:
        closedError = true

      check closedError
      echo "✅ Channel closed error works"
    except Exception as e:
      echo "❌ Channel closed error test error: ", e.msg
      check false

suite "Edge Case Tests":
  test "Empty TaskGroup join":
    try:
      var group = initTaskGroup()

      # Join without spawning any tasks should complete immediately
      await group.join()
      check group.taskCount == 0
      echo "✅ Empty TaskGroup join works"
    except Exception as e:
      echo "❌ Empty TaskGroup error: ", e.msg
      check false

  test "Double cancellation":
    try:
      var scope = initCancelScope()

      scope.cancel()
      check scope.cancelled

      # Second cancellation should be safe
      scope.cancel()
      check scope.cancelled
      echo "✅ Double cancellation works"
    except Exception as e:
      echo "❌ Double cancellation error: ", e.msg
      check false

  test "Zero capacity channel":
    try:
      # Zero capacity should still work for immediate transfer
      let chan = newChannel[int](0, ChannelMode.SPSC)

      var sendComplete = false
      var receiveComplete = false

      proc sender(): Future[void] {.async.} =
        await chan.send(42)
        sendComplete = true

      proc receiver(): Future[void] {.async.} =
        let value = await chan.recv()
        check value == 42
        receiveComplete = true

      # Start both concurrently
      let senderFuture = sender()
      let receiverFuture = receiver()

      await senderFuture
      await receiverFuture

      check sendComplete
      check receiveComplete
      echo "✅ Zero capacity channel works"
    except Exception as e:
      echo "❌ Zero capacity channel error: ", e.msg
      check false

suite "Resource Limit Tests":
  test "Large TaskGroup handling":
    try:
      var group = initTaskGroup()
      var completedTasks = 0

      proc quickTask(id: int): Future[void] {.async.} =
        await sleepAsync(1.milliseconds)
        inc completedTasks

      # Spawn many tasks
      for i in 1..100:
        discard group.spawn(proc(): Future[void] {.async.} = await quickTask(i))

      check group.taskCount == 100

      await group.join()
      check completedTasks == 100
      check group.taskCount == 0
      echo "✅ Large TaskGroup handling works"
    except Exception as e:
      echo "❌ Large TaskGroup error: ", e.msg
      check false

  test "Channel overflow handling":
    try:
      let chan = newChannel[int](2, ChannelMode.SPSC)  # Small capacity
      var overflowHandled = false

      # Fill channel
      await chan.send(1)
      await chan.send(2)

      # Try to send more with timeout
      try:
        await chan.sendWithTimeout(3, 50)  # 50ms timeout
      except TimeoutError:
        overflowHandled = true

      check overflowHandled
      echo "✅ Channel overflow handling works"
    except Exception as e:
      echo "❌ Channel overflow error: ", e.msg
      check false

suite "Concurrent Access Tests":
  test "Multiple readers/writers":
    try:
      let chan = newChannel[int](10, ChannelMode.MPMC)
      var totalSent = 0
      var totalReceived = 0

      proc writer(start: int): Future[void] {.async.} =
        for i in start..<(start + 5):
          await chan.send(i)
          inc totalSent

      proc reader(): Future[void] {.async.} =
        for i in 1..5:
          discard await chan.recv()
          inc totalReceived

      # Start multiple writers and readers
      let writers = @[writer(1), writer(6)]
      let readers = @[reader(), reader()]

      await allFutures(writers & readers)

      check totalSent == 10
      check totalReceived == 10
      echo "✅ Multiple readers/writers work"
    except Exception as e:
      echo "❌ Concurrent access error: ", e.msg
      check false

echo "✅ Error handling and edge case tests completed"