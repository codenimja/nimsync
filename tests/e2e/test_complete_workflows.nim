## End-to-End Tests for Complete nimsync Workflows
##
## Tests realistic scenarios that combine multiple nimsync components

import std/[sequtils, atomics, tables]
import ../support/test_fixtures

suite "E2E Complete Workflows":

  setup:
    setupTestEnvironment()

  teardown:
    cleanupTestResources()

  asyncTest "Producer-Consumer Pipeline with TaskGroup":
    # Realistic scenario: Process messages through a pipeline
    const messageCount = 1000
    let chan = createTestChannel[TestMessage](256, ChannelMode.SPSC)
    let results = createTestChannel[string](256, ChannelMode.SPSC)

    var processedCount = 0

    await taskGroup(TaskPolicy.FailFast):
      # Producer task
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< messageCount:
          await chan.send(generateTestMessage(i))
        chan.close()
      )

      # Processor task
      discard g.spawn(proc() {.async.} =
        while true:
          try:
            let msg = await chan.recv()
            let processed = fmt"Processed: {msg.payload}"
            await results.send(processed)
          except ChannelClosedError:
            break
        results.close()
      )

      # Consumer task
      discard g.spawn(proc() {.async.} =
        while true:
          try:
            discard await results.recv()
            processedCount += 1
          except ChannelClosedError:
            break
      )

    check processedCount == messageCount

  asyncTest "Distributed Work with Multiple TaskGroups":
    # Scenario: Distribute work across multiple worker groups
    const totalWork = 1000
    const workerGroups = 4
    const workPerGroup = totalWork div workerGroups

    let workQueue = createTestChannel[int](totalWork, ChannelMode.MPMC)
    let results = createTestChannel[int](totalWork, ChannelMode.MPMC)
    let completedWork = Atomic[int]()

    # Fill work queue
    for i in 0 ..< totalWork:
      await workQueue.send(i)
    workQueue.close()

    # Create multiple worker groups
    var workerTasks: seq[Future[void]] = @[]

    for groupId in 0 ..< workerGroups:
      workerTasks.add(proc() {.async.} =
        await taskGroup(TaskPolicy.FailFast):
          # Each group spawns multiple workers
          for workerId in 0 ..< 4:
            discard g.spawn(proc() {.async.} =
              while true:
                try:
                  let work = await workQueue.recv()
                  # Simulate work processing
                  await sleepAsync(1.milliseconds)
                  let result = work * 2
                  await results.send(result)
                  discard completedWork.fetchAdd(1, moRelaxed)
                except ChannelClosedError:
                  break
            )
      )

    # Wait for all worker groups to complete
    await allFutures(workerTasks)

    check completedWork.load(moAcquire) == totalWork

  asyncTest "Stream Processing Pipeline with Backpressure":
    # Scenario: High-throughput stream processing with backpressure control
    var inputStream = createTestStream[int](BackpressurePolicy.Block, 100)
    var processedItems = 0

    await taskGroup(TaskPolicy.FailFast):
      # Data producer
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< 500:
          await inputStream.send(i)
        inputStream.close()
      )

      # Stream processor with transformations
      discard g.spawn(proc() {.async.} =
        let source = Source[int](stream: addr inputStream)
        let doubled = source.map(proc(x: int): int = x * 2)
        let filtered = doubled.filter(proc(x: int): bool = x mod 4 == 0)
        let batched = filtered.batch(10)

        while true:
          let batch = await batched.stream[].receive()
          if batch.isNone:
            break

          let items = batch.get()
          processedItems += items.len
      )

    # Should have processed filtered and batched data
    check processedItems > 0

  asyncTest "Actor System with Supervision and Error Recovery":
    # Scenario: Actor system with supervision handling failures
    actorSystem:
      var messagesProcessed = 0
      var errorsHandled = 0

      type
        WorkMessage = object
          id: int
          shouldFail: bool

        WorkerState = object
          processed: int

      # Create worker actor with error handling
      var workerBehavior = actor(WorkerState(processed: 0)):
        handle(WorkMessage, proc(state: var WorkerState, msg: WorkMessage) {.async.} =
          if msg.shouldFail:
            raise newException(ValueError, fmt"Simulated failure for message {msg.id}")

          state.processed += 1
          messagesProcessed += 1
        )

      let worker = system.spawn(workerBehavior)

      # Send mix of successful and failing messages
      for i in 0 ..< 20:
        let shouldFail = (i mod 5 == 0)  # Every 5th message fails
        discard worker.send(WorkMessage(id: i, shouldFail: shouldFail))

      # Give time for message processing
      await sleepAsync(100.milliseconds)

      # Should have processed some messages despite failures
      check messagesProcessed > 0

  asyncTest "Timeout and Cancellation in Complex Workflow":
    # Scenario: Complex workflow with timeouts and graceful cancellation
    var completedPhases = 0

    try:
      await withTimeout(500.milliseconds):
        await taskGroup(TaskPolicy.FailFast):
          # Phase 1: Quick setup
          discard g.spawn(proc() {.async.} =
            await sleepAsync(50.milliseconds)
            completedPhases += 1
          )

          # Phase 2: Medium work
          discard g.spawn(proc() {.async.} =
            await sleepAsync(150.milliseconds)
            completedPhases += 1
          )

          # Phase 3: Long work (will be cancelled)
          discard g.spawn(proc() {.async.} =
            await sleepAsync(1000.milliseconds)  # Exceeds timeout
            completedPhases += 1
          )

      fail("Should have timed out")
    except CancelledError:
      # Expected timeout
      check completedPhases >= 2  # First two phases should complete

  asyncTest "High-Throughput Message Routing":
    # Scenario: Route messages between multiple channels based on content
    const messageCount = 1000
    let inputChan = createTestChannel[TestMessage](256, ChannelMode.SPSC)
    let evenChan = createTestChannel[TestMessage](128, ChannelMode.SPSC)
    let oddChan = createTestChannel[TestMessage](128, ChannelMode.SPSC)

    var evenCount = 0
    var oddCount = 0

    await taskGroup(TaskPolicy.FailFast):
      # Message producer
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< messageCount:
          await inputChan.send(generateTestMessage(i))
        inputChan.close()
      )

      # Message router
      discard g.spawn(proc() {.async.} =
        while true:
          try:
            let msg = await inputChan.recv()
            if msg.id mod 2 == 0:
              await evenChan.send(msg)
            else:
              await oddChan.send(msg)
          except ChannelClosedError:
            break

        evenChan.close()
        oddChan.close()
      )

      # Even message processor
      discard g.spawn(proc() {.async.} =
        while true:
          try:
            discard await evenChan.recv()
            evenCount += 1
          except ChannelClosedError:
            break
      )

      # Odd message processor
      discard g.spawn(proc() {.async.} =
        while true:
          try:
            discard await oddChan.recv()
            oddCount += 1
          except ChannelClosedError:
            break
      )

    check evenCount + oddCount == messageCount
    check abs(evenCount - oddCount) <= 1  # Should be roughly equal

  asyncTest "Memory-Efficient Batch Processing":
    # Scenario: Process large dataset in batches to control memory usage
    const totalItems = 10000
    const batchSize = 100

    var stream = createTestStream[int](BackpressurePolicy.Block, batchSize * 2)
    var batchesProcessed = 0
    var totalProcessed = 0

    await taskGroup(TaskPolicy.FailFast):
      # Data producer
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< totalItems:
          await stream.send(i)
        stream.close()
      )

      # Batch processor
      discard g.spawn(proc() {.async.} =
        while true:
          let batch = await stream.receiveBatch(batchSize)
          if batch.len == 0:
            break

          # Process batch
          for item in batch:
            totalProcessed += 1

          batchesProcessed += 1

          # Simulate batch processing time
          await sleepAsync(1.milliseconds)
      )

    check totalProcessed == totalItems
    check batchesProcessed == (totalItems div batchSize)

  asyncTest "Fault-Tolerant Service Architecture":
    # Scenario: Service with retry logic and circuit breaker pattern
    let requestChan = createTestChannel[int](100, ChannelMode.MPMC)
    let responseChan = createTestChannel[string](100, ChannelMode.MPMC)

    var successfulRequests = 0
    var failedRequests = 0
    var retriesAttempted = 0

    let errorInjector = createErrorInjector(0.3)  # 30% failure rate

    await taskGroup(TaskPolicy.CollectErrors):  # Continue despite service errors
      # Request generator
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< 100:
          await requestChan.send(i)
        requestChan.close()
      )

      # Service with retry logic
      for serviceId in 0 ..< 3:
        discard g.spawn(proc() {.async.} =
          while true:
            try:
              let request = await requestChan.recv()

              # Retry logic
              var attempt = 0
              while attempt < 3:
                try:
                  maybeInjectError(errorInjector)

                  # Simulate service work
                  await sleepAsync(10.milliseconds)

                  await responseChan.send(fmt"Service-{serviceId}-Response-{request}")
                  successfulRequests += 1
                  break

                except CatchableError:
                  attempt += 1
                  retriesAttempted += 1
                  if attempt < 3:
                    await sleepAsync(50.milliseconds)  # Backoff
                  else:
                    failedRequests += 1

            except ChannelClosedError:
              break
        )

      # Response collector
      discard g.spawn(proc() {.async.} =
        var responses = 0
        while responses < 100:
          try:
            discard await withTimeout(proc(): Future[string] {.async.} =
              return await responseChan.recv()
            , 2.seconds)
            responses += 1
          except AsyncTimeoutError:
            break
          except ChannelClosedError:
            break
      )

    check successfulRequests > 0
    check retriesAttempted > 0

    if testConfig.verbose:
      echo fmt"Fault tolerance test: {successfulRequests} successful, {failedRequests} failed, {retriesAttempted} retries"

  asyncTest "Real-time Data Processing Pipeline":
    # Scenario: Real-time processing with different priority levels
    let highPriorityChan = createTestChannel[TestMessage](50, ChannelMode.SPSC)
    let normalPriorityChan = createTestChannel[TestMessage](100, ChannelMode.SPSC)
    let resultChan = createTestChannel[string](200, ChannelMode.MPMC)

    var highPriorityProcessed = 0
    var normalPriorityProcessed = 0

    await taskGroup(TaskPolicy.FailFast):
      # High priority data generator
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< 50:
          let msg = TestMessage(id: i, payload: fmt"HIGH-{i}", timestamp: getMonoTime())
          await highPriorityChan.send(msg)
        highPriorityChan.close()
      )

      # Normal priority data generator
      discard g.spawn(proc() {.async.} =
        for i in 0 ..< 100:
          let msg = TestMessage(id: i + 1000, payload: fmt"NORMAL-{i}", timestamp: getMonoTime())
          await normalPriorityChan.send(msg)
          await sleepAsync(2.milliseconds)  # Slower generation
        normalPriorityChan.close()
      )

      # Priority processor (prefers high priority)
      discard g.spawn(proc() {.async.} =
        var highClosed = false
        var normalClosed = false

        while not (highClosed and normalClosed):
          # Try high priority first
          if not highClosed:
            try:
              let msg = await withTimeout(proc(): Future[TestMessage] {.async.} =
                return await highPriorityChan.recv()
              , 1.milliseconds)

              await resultChan.send(fmt"PROCESSED: {msg.payload}")
              highPriorityProcessed += 1
              continue
            except AsyncTimeoutError:
              # No high priority messages available
              discard
            except ChannelClosedError:
              highClosed = true

          # Process normal priority
          if not normalClosed:
            try:
              let msg = await withTimeout(proc(): Future[TestMessage] {.async.} =
                return await normalPriorityChan.recv()
              , 10.milliseconds)

              await resultChan.send(fmt"PROCESSED: {msg.payload}")
              normalPriorityProcessed += 1
            except AsyncTimeoutError:
              # No normal priority messages available
              continue
            except ChannelClosedError:
              normalClosed = true

        resultChan.close()
      )

    check highPriorityProcessed == 50
    check normalPriorityProcessed == 100

    if testConfig.verbose:
      echo fmt"Priority processing: {highPriorityProcessed} high priority, {normalPriorityProcessed} normal priority"