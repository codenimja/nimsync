## Unit Tests for MPMC (Multi Producer Multi Consumer) Channels
##
## Tests the concurrent MPMC channel implementation with multiple producers and consumers

import std/[sequtils, atomics]
import ../../support/test_fixtures

suite "MPMC Channel Unit Tests":

  setup:
    setupTestEnvironment()

  teardown:
    cleanupTestResources()

  asyncTest "Basic MPMC operations":
    let chan = createTestChannel[int](MEDIUM_BUFFER_SIZE, ChannelMode.MPMC)

    # Basic send/receive should work like SPSC
    await chan.send(42)
    let received = await chan.recv()
    check received == 42

  asyncTest "Multiple producers single consumer":
    let chan = createTestChannel[TestMessage](LARGE_BUFFER_SIZE, ChannelMode.MPMC)
    const producerCount = 4
    const messagesPerProducer = 250
    const totalMessages = producerCount * messagesPerProducer

    let receivedCount = Atomic[int]()
    var allReceived: seq[TestMessage] = @[]

    # Create multiple producers
    var producers: seq[Future[void]] = @[]
    for producerId in 0 ..< producerCount:
      producers.add(proc(): Future[void] {.async.} =
        for msgId in 0 ..< messagesPerProducer:
          let msg = TestMessage(
            id: producerId * messagesPerProducer + msgId,
            payload: fmt"Producer-{producerId}-Message-{msgId}",
            timestamp: getMonoTime()
          )
          await chan.send(msg)
      )

    # Single consumer
    let consumer = proc(): Future[void] {.async.} =
      for i in 0 ..< totalMessages:
        let msg = await chan.recv()
        allReceived.add(msg)
        discard receivedCount.fetchAdd(1, moRelaxed)

    # Start all producers and consumer
    var allTasks = producers
    allTasks.add(consumer())

    await allFutures(allTasks)

    # Verify all messages received
    check receivedCount.load(moAcquire) == totalMessages
    check allReceived.len == totalMessages

    # Verify all messages are unique (no duplicates)
    var ids: seq[int] = @[]
    for msg in allReceived:
      ids.add(msg.id)
    ids.sort()

    for i in 0 ..< totalMessages:
      check ids[i] == i

  asyncTest "Single producer multiple consumers":
    let chan = createTestChannel[int](LARGE_BUFFER_SIZE, ChannelMode.MPMC)
    const consumerCount = 4
    const totalMessages = 1000

    let processedCount = Atomic[int]()
    var consumerResults: array[4, Atomic[int]]

    # Single producer
    let producer = proc(): Future[void] {.async.} =
      for i in 0 ..< totalMessages:
        await chan.send(i)
      chan.close()

    # Multiple consumers
    var consumers: seq[Future[void]] = @[]
    for consumerId in 0 ..< consumerCount:
      consumers.add(proc(): Future[void] {.async.} =
        var localCount = 0
        while true:
          try:
            discard await chan.recv()
            localCount += 1
            discard processedCount.fetchAdd(1, moRelaxed)
          except ChannelClosedError:
            break
        consumerResults[consumerId].store(localCount, moRelaxed)
      )

    # Run producer and all consumers
    await allFutures(@[producer()] & consumers)

    # Verify all messages processed exactly once
    check processedCount.load(moAcquire) == totalMessages

    # Verify work distribution (each consumer should get some messages)
    var totalDistributed = 0
    for i in 0 ..< consumerCount:
      let count = consumerResults[i].load(moAcquire)
      totalDistributed += count
      check count > 0  # Each consumer should process at least some messages

    check totalDistributed == totalMessages

  asyncTest "Multiple producers multiple consumers":
    let chan = createTestChannel[BenchmarkMessage](LARGE_BUFFER_SIZE, ChannelMode.MPMC)
    const producerCount = 3
    const consumerCount = 3
    const messagesPerProducer = 100
    const totalMessages = producerCount * messagesPerProducer

    let sentCount = Atomic[int]()
    let receivedCount = Atomic[int]()

    # Multiple producers
    var producers: seq[Future[void]] = @[]
    for producerId in 0 ..< producerCount:
      producers.add(proc(): Future[void] {.async.} =
        for msgId in 0 ..< messagesPerProducer:
          let msg = generateBenchmarkMessage((producerId * messagesPerProducer + msgId).int64)
          await chan.send(msg)
          discard sentCount.fetchAdd(1, moRelaxed)
      )

    # Multiple consumers
    var consumers: seq[Future[void]] = @[]
    for consumerId in 0 ..< consumerCount:
      consumers.add(proc(): Future[void] {.async.} =
        # Each consumer tries to process messages until all are done
        while receivedCount.load(moAcquire) < totalMessages:
          try:
            discard await withTimeout(proc(): Future[BenchmarkMessage] {.async.} =
              return await chan.recv()
            , SHORT_TIMEOUT)
            discard receivedCount.fetchAdd(1, moRelaxed)
          except AsyncTimeoutError:
            # No more messages available
            break
          except ChannelClosedError:
            break
      )

    # Wait for all producers to finish
    await allFutures(producers)

    # Close channel to signal consumers
    chan.close()

    # Wait for all consumers to finish
    await allFutures(consumers)

    # Verify message counts
    check sentCount.load(moAcquire) == totalMessages
    check receivedCount.load(moAcquire) == totalMessages

  asyncTestWithMetrics "MPMC throughput benchmark", TARGET_MPMC_THROUGHPUT.int64:
    testConfig.expectedThroughput = TARGET_MPMC_THROUGHPUT

    let chan = createTestChannel[int](LARGE_BUFFER_SIZE, ChannelMode.MPMC)
    const producerCount = 2
    const consumerCount = 2
    const messagesPerProducer = SMALL_TEST_SIZE div producerCount
    const totalMessages = producerCount * messagesPerProducer

    let processed = Atomic[int]()

    # Producers
    var producers: seq[Future[void]] = @[]
    for i in 0 ..< producerCount:
      producers.add(proc(): Future[void] {.async.} =
        for j in 0 ..< messagesPerProducer:
          await chan.send(i * messagesPerProducer + j)
      )

    # Consumers
    var consumers: seq[Future[void]] = @[]
    for i in 0 ..< consumerCount:
      consumers.add(proc(): Future[void] {.async.} =
        while processed.load(moAcquire) < totalMessages:
          try:
            discard await withTimeout(proc(): Future[int] {.async.} =
              return await chan.recv()
            , MEDIUM_TIMEOUT)
            discard processed.fetchAdd(1, moRelaxed)
          except AsyncTimeoutError:
            break
          except ChannelClosedError:
            break
      )

    let startTime = getMonoTime()

    # Start all tasks
    await allFutures(producers)
    chan.close()
    await allFutures(consumers)

    let endTime = getMonoTime()

    let duration = endTime - startTime
    let throughput = totalMessages.float64 * 1_000_000_000.0 / duration.inNanoseconds.float64

    if testConfig.verbose:
      echo fmt"MPMC throughput: {throughput:.0f} messages/second"

    check processed.load(moAcquire) == totalMessages
    check throughput > TARGET_MPMC_THROUGHPUT * 0.3  # Allow more tolerance for MPMC

  asyncTest "Contention handling under high load":
    let chan = createTestChannel[int](MEDIUM_BUFFER_SIZE, ChannelMode.MPMC)
    const contendingProducers = 8
    const contendingConsumers = 8
    const messagesPerProducer = 50
    const totalMessages = contendingProducers * messagesPerProducer

    let sentCount = Atomic[int]()
    let receivedCount = Atomic[int]()

    # High contention producers
    var producers: seq[Future[void]] = @[]
    for i in 0 ..< contendingProducers:
      producers.add(proc(): Future[void] {.async.} =
        for j in 0 ..< messagesPerProducer:
          await chan.send(i * messagesPerProducer + j)
          discard sentCount.fetchAdd(1, moRelaxed)
          # Small delay to increase contention
          await sleepAsync(1.milliseconds)
      )

    # High contention consumers
    var consumers: seq[Future[void]] = @[]
    for i in 0 ..< contendingConsumers:
      consumers.add(proc(): Future[void] {.async.} =
        while receivedCount.load(moAcquire) < totalMessages:
          try:
            discard await withTimeout(proc(): Future[int] {.async.} =
              return await chan.recv()
            , MEDIUM_TIMEOUT)
            discard receivedCount.fetchAdd(1, moRelaxed)
          except AsyncTimeoutError:
            break
          except ChannelClosedError:
            break
      )

    # Run with high contention
    await allFutures(producers)
    chan.close()
    await allFutures(consumers)

    # Should handle contention gracefully
    check sentCount.load(moAcquire) == totalMessages
    check receivedCount.load(moAcquire) == totalMessages

  asyncTest "Message ordering under concurrency":
    let chan = createTestChannel[TestMessage](LARGE_BUFFER_SIZE, ChannelMode.MPMC)
    const producerCount = 3
    const messagesPerProducer = 100

    var allMessages: seq[TestMessage] = @[]

    # Producers with unique message IDs per producer
    var producers: seq[Future[void]] = @[]
    for producerId in 0 ..< producerCount:
      producers.add(proc(): Future[void] {.async.} =
        for msgIdx in 0 ..< messagesPerProducer:
          let msg = TestMessage(
            id: producerId * 10000 + msgIdx,  # Ensure unique IDs
            payload: fmt"P{producerId}M{msgIdx}",
            timestamp: getMonoTime()
          )
          await chan.send(msg)
      )

    # Single consumer to collect all messages
    let consumer = proc(): Future[void] {.async.} =
      for i in 0 ..< (producerCount * messagesPerProducer):
        let msg = await chan.recv()
        allMessages.add(msg)

    await allFutures(producers & @[consumer()])

    # Verify all messages received and are unique
    check allMessages.len == producerCount * messagesPerProducer

    var seenIds: seq[int] = @[]
    for msg in allMessages:
      check msg.id notin seenIds  # No duplicates
      seenIds.add(msg.id)

  asyncTest "Error propagation in MPMC scenario":
    let chan = createTestChannel[int](SMALL_BUFFER_SIZE, ChannelMode.MPMC)
    let errorInjector = createErrorInjector(0.1)  # 10% failure rate

    let successfulOps = Atomic[int]()
    let failedOps = Atomic[int]()

    # Producers with error injection
    var producers: seq[Future[void]] = @[]
    for i in 0 ..< 3:
      producers.add(proc(): Future[void] {.async.} =
        for j in 0 ..< 50:
          try:
            maybeInjectError(errorInjector)
            await chan.send(i * 50 + j)
            discard successfulOps.fetchAdd(1, moRelaxed)
          except CatchableError:
            discard failedOps.fetchAdd(1, moRelaxed)
      )

    await allFutures(producers)
    chan.close()

    # Some operations should succeed despite errors
    check successfulOps.load(moAcquire) > 0

    if testConfig.verbose:
      echo fmt"MPMC error test: {successfulOps.load(moAcquire)} successful, {failedOps.load(moAcquire)} failed"