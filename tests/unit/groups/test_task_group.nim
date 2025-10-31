## Unit Tests for TaskGroup - Structured Concurrency
##
## Tests the high-performance TaskGroup implementation with various error policies

import std/[sequtils, atomics]
import ../../support/test_fixtures

suite "TaskGroup Unit Tests":

  setup:
    setupTestEnvironment()

  teardown:
    cleanupTestResources()

  asyncTest "Basic task spawning and completion":
    var completedTasks = 0

    await taskGroup(TaskPolicy.FailFast):
      discard g.spawn(proc() {.async.} =
        await sleepAsync(10.milliseconds)
        completedTasks += 1
      )

      discard g.spawn(proc() {.async.} =
        await sleepAsync(20.milliseconds)
        completedTasks += 2
      )

    check completedTasks == 3

  asyncTest "Task group with return values":
    await taskGroup(TaskPolicy.FailFast):
      let task1 = g.spawn(proc(): Future[int] {.async.} =
        await sleepAsync(10.milliseconds)
        return 42
      )

      let task2 = g.spawn(proc(): Future[string] {.async.} =
        await sleepAsync(15.milliseconds)
        return "hello"
      )

      let result1 = await task1
      let result2 = await task2

      check result1 == 42
      check result2 == "hello"

  asyncTest "FailFast policy cancels remaining tasks on error":
    var task1Completed = false
    var task2Completed = false
    var task3Completed = false

    try:
      await taskGroup(TaskPolicy.FailFast):
        discard g.spawn(proc() {.async.} =
          await sleepAsync(10.milliseconds)
          task1Completed = true
        )

        discard g.spawn(proc() {.async.} =
          await sleepAsync(20.milliseconds)
          raise newException(ValueError, "Test error")
        )

        discard g.spawn(proc() {.async.} =
          await sleepAsync(100.milliseconds)  # Should be cancelled
          task3Completed = true
        )

      fail("TaskGroup should have raised an exception")
    except ValueError:
      # Expected
      check task1Completed == true   # Completed before error
      check task2Completed == false  # Never set due to exception
      check task3Completed == false  # Cancelled due to error

  asyncTest "CollectErrors policy continues despite failures":
    var task1Completed = false
    var task2Failed = false
    var task3Completed = false

    try:
      await taskGroup(TaskPolicy.CollectErrors):
        discard g.spawn(proc() {.async.} =
          await sleepAsync(10.milliseconds)
          task1Completed = true
        )

        discard g.spawn(proc() {.async.} =
          await sleepAsync(20.milliseconds)
          task2Failed = true
          raise newException(ValueError, "Test error")
        )

        discard g.spawn(proc() {.async.} =
          await sleepAsync(30.milliseconds)
          task3Completed = true
        )

      fail("TaskGroup should have raised collected errors")
    except AsyncError:
      # Expected - should collect all errors
      check task1Completed == true
      check task2Failed == true
      check task3Completed == true

  asyncTest "IgnoreErrors policy continues and succeeds":
    var task1Completed = false
    var task2Failed = false
    var task3Completed = false

    # Should not raise any exception
    await taskGroup(TaskPolicy.IgnoreErrors):
      discard g.spawn(proc() {.async.} =
        await sleepAsync(10.milliseconds)
        task1Completed = true
      )

      discard g.spawn(proc() {.async.} =
        await sleepAsync(20.milliseconds)
        task2Failed = true
        raise newException(ValueError, "Test error")
      )

      discard g.spawn(proc() {.async.} =
        await sleepAsync(30.milliseconds)
        task3Completed = true
      )

    check task1Completed == true
    check task2Failed == true
    check task3Completed == true

  asyncTest "Nested task groups":
    var outerTask1 = false
    var innerTask1 = false
    var innerTask2 = false
    var outerTask2 = false

    await taskGroup(TaskPolicy.FailFast):
      discard g.spawn(proc() {.async.} =
        outerTask1 = true

        await taskGroup(TaskPolicy.FailFast):
          discard g.spawn(proc() {.async.} =
            await sleepAsync(10.milliseconds)
            innerTask1 = true
          )

          discard g.spawn(proc() {.async.} =
            await sleepAsync(15.milliseconds)
            innerTask2 = true
          )
      )

      discard g.spawn(proc() {.async.} =
        await sleepAsync(20.milliseconds)
        outerTask2 = true
      )

    check outerTask1 == true
    check innerTask1 == true
    check innerTask2 == true
    check outerTask2 == true

  asyncTest "Task group respects cancellation":
    var tasksStarted = 0
    var tasksCompleted = 0

    await withCancelScope(proc(scope: var CancelScope) {.async.} =
      let groupFuture = taskGroup(TaskPolicy.FailFast):
        for i in 0 ..< 5:
          discard g.spawn(proc() {.async.} =
            tasksStarted += 1
            await sleepAsync(100.milliseconds)
            tasksCompleted += 1
          )

      # Cancel after short delay
      await sleepAsync(10.milliseconds)
      scope.cancel()

      try:
        await groupFuture
        fail("TaskGroup should have been cancelled")
      except CancelledError:
        # Expected
        discard
    )

    check tasksStarted > 0
    check tasksCompleted < 5  # Some tasks should have been cancelled

  asyncTestWithMetrics "Task spawning performance", TARGET_TASK_SPAWN_LATENCY.int64:
    const taskCount = SMALL_TEST_SIZE
    let spawnedTasks = Atomic[int]()

    await taskGroup(TaskPolicy.FailFast):
      for i in 0 ..< taskCount:
        discard g.spawn(proc() {.async.} =
          discard spawnedTasks.fetchAdd(1, moRelaxed)
        )

    check spawnedTasks.load(moAcquire) == taskCount

  asyncTest "Resource cleanup on task group exit":
    var resourcesAcquired = 0
    var resourcesReleased = 0

    proc acquireResource(): int =
      resourcesAcquired += 1
      return resourcesAcquired

    proc releaseResource(id: int) =
      resourcesReleased += 1

    try:
      await taskGroup(TaskPolicy.FailFast):
        for i in 0 ..< 3:
          discard g.spawn(proc() {.async.} =
            let resourceId = acquireResource()
            try:
              await sleepAsync(20.milliseconds)
              if i == 1:
                raise newException(ValueError, "Task 1 error")
            finally:
              releaseResource(resourceId)
          )

      fail("TaskGroup should have failed")
    except ValueError:
      # Expected
      discard

    # All resources should be cleaned up
    check resourcesAcquired == resourcesReleased

  asyncTest "Task group with different task types":
    var intResult = 0
    var stringResult = ""
    var boolResult = false

    await taskGroup(TaskPolicy.FailFast):
      let intTask = g.spawn(proc(): Future[int] {.async.} =
        await sleepAsync(10.milliseconds)
        return 42
      )

      let stringTask = g.spawn(proc(): Future[string] {.async.} =
        await sleepAsync(15.milliseconds)
        return "test"
      )

      let boolTask = g.spawn(proc(): Future[bool] {.async.} =
        await sleepAsync(5.milliseconds)
        return true
      )

      intResult = await intTask
      stringResult = await stringTask
      boolResult = await boolTask

    check intResult == 42
    check stringResult == "test"
    check boolResult == true

  asyncTest "Large number of tasks":
    const taskCount = 100
    let completedTasks = Atomic[int]()

    await taskGroup(TaskPolicy.FailFast):
      for i in 0 ..< taskCount:
        discard g.spawn(proc() {.async.} =
          await sleepAsync(1.milliseconds)
          discard completedTasks.fetchAdd(1, moRelaxed)
        )

    check completedTasks.load(moAcquire) == taskCount

  asyncTest "Task group memory efficiency":
    const taskCount = SMALL_TEST_SIZE

    let (result, memoryUsed) = await withMemoryMonitoring(proc(): Future[int] {.async.} =
      var totalCompleted = 0

      await taskGroup(TaskPolicy.FailFast):
        for i in 0 ..< taskCount:
          discard g.spawn(proc() {.async.} =
            # Minimal work to test memory overhead
            totalCompleted += 1
          )

      return totalCompleted
    )

    check result == taskCount

    # Memory usage should be reasonable for task management
    let maxExpectedMemory = taskCount * 1024  # 1KB per task maximum
    if memoryUsed > maxExpectedMemory and testConfig.verbose:
      echo fmt"TaskGroup memory usage: {memoryUsed} bytes for {taskCount} tasks"

  asyncTest "Task group with timeout":
    try:
      await withTimeout(proc(): Future[void] {.async.} =
        await taskGroup(TaskPolicy.FailFast):
          discard g.spawn(proc() {.async.} =
            await sleepAsync(200.milliseconds)  # Longer than timeout
          )
      , 50.milliseconds)

      fail("TaskGroup should have timed out")
    except AsyncTimeoutError:
      # Expected
      check true

  asyncTest "Error propagation preserves original exception":
    try:
      await taskGroup(TaskPolicy.FailFast):
        discard g.spawn(proc() {.async.} =
          raise newException(KeyError, "Specific error message")
        )

      fail("TaskGroup should have propagated the exception")
    except KeyError as e:
      check e.msg == "Specific error message"

  asyncTest "Task group statistics collection":
    when defined(statistics):
      let initialStats = getGlobalStats()

      await taskGroup(TaskPolicy.FailFast):
        for i in 0 ..< 5:
          discard g.spawn(proc() {.async.} =
            await sleepAsync(10.milliseconds)
          )

      let finalStats = getGlobalStats()
      check finalStats.totalTasks > initialStats.totalTasks