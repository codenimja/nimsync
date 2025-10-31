## TaskGroup functionality test
##
## Tests TaskGroup spawn, join, error handling, and cancellation behavior

import std/[unittest, strutils]
import ../../src/nimsync

suite "TaskGroup Functionality Tests":
  test "TaskGroup creation and basic properties":
    var group = initTaskGroup()
    check group.active
    check not group.cancelled
    check group.taskCount == 0
    echo "✅ TaskGroup creation works"

  test "TaskGroup spawn and join":
    try:
      var group = initTaskGroup()

      # Test spawning a simple task
      proc simpleTask(): Future[void] {.async.} =
        await chronos.sleepAsync(10.milliseconds)

      let taskId = group.spawn(simpleTask)
      check group.taskCount == 1

      # Join should complete successfully
      await group.join()
      check group.taskCount == 0
      echo "✅ TaskGroup spawn and join works"
    except Exception as e:
      echo "❌ TaskGroup spawn/join error: ", e.msg
      check false

  test "TaskGroup multiple tasks":
    try:
      var group = initTaskGroup()
      var completedTasks = 0

      proc countingTask(id: int): Future[void] {.async.} =
        await chronos.sleepAsync((id * 5).milliseconds)
        inc completedTasks

      # Spawn multiple tasks
      discard group.spawn(proc(): Future[void] {.async.} = await countingTask(1))
      discard group.spawn(proc(): Future[void] {.async.} = await countingTask(2))
      discard group.spawn(proc(): Future[void] {.async.} = await countingTask(3))

      check group.taskCount == 3

      await group.join()
      check completedTasks == 3
      check group.taskCount == 0
      echo "✅ Multiple tasks execution works"
    except Exception as e:
      echo "❌ Multiple tasks error: ", e.msg
      check false

  test "TaskGroup cancellation":
    try:
      var group = initTaskGroup()
      var taskStarted = false
      var taskCompleted = false

      proc longTask(): Future[void] {.async.} =
        taskStarted = true
        await chronos.sleepAsync(1000.milliseconds)  # Long running task
        taskCompleted = true

      discard group.spawn(longTask)

      # Give task time to start
      await chronos.sleepAsync(10.milliseconds)
      check taskStarted

      # Cancel the group
      group.cancel()
      check group.cancelled

      # Join should complete quickly due to cancellation
      await group.join()
      check not taskCompleted  # Task should not have completed
      echo "✅ TaskGroup cancellation works"
    except Exception as e:
      echo "❌ TaskGroup cancellation error: ", e.msg
      check false

echo "✅ TaskGroup functionality tests completed"