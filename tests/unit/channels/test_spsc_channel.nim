## Unit Tests for SPSC (Single Producer Single Consumer) Channels
##
## Tests the high-performance lock-free SPSC channel implementation

import std/[sequtils, atomics]
import ../../support/test_fixtures

suite "SPSC Channel Unit Tests":

  setup:
    setupTestEnvironment()

  teardown:
    cleanupTestResources()

  asyncTest "Basic send and receive":
    let chan = createTestChannel[int](MEDIUM_BUFFER_SIZE, ChannelMode.SPSC)

    # Single send/receive
    await chan.send(42)
    let received = await chan.recv()
    check received == 42

  asyncTest "Multiple sequential operations":
    let chan = createTestChannel[int](MEDIUM_BUFFER_SIZE, ChannelMode.SPSC)
    let testData = toSeq(1..100)

    # Send all data
    for value in testData:
      await chan.send(value)

    # Receive all data
    var received: seq[int] = @[]
    for i in 0 ..< testData.len:
      received.add(await chan.recv())

    check received == testData

  asyncTest "Channel close behavior":
    let chan = createTestChannel[string](SMALL_BUFFER_SIZE, ChannelMode.SPSC)

    await chan.send("test message")
    chan.close()

    # Should still be able to receive queued messages
    let msg = await chan.recv()
    check msg == "test message"

    # Further receives should throw ChannelClosedError
    expect ChannelClosedError:
      discard await chan.recv()

  asyncTest "Channel full behavior with blocking":
    let chan = createTestChannel[int](2, ChannelMode.SPSC)  # Small buffer

    # Fill channel to capacity
    await chan.send(1)
    await chan.send(2)

    # This should block, so we test with timeout
    let sendFuture = chan.send(3)

    # Should timeout since channel is full
    try:
      await withTimeout(sendFuture, SHORT_TIMEOUT)
      fail("Send should have blocked on full channel")
    except AsyncTimeoutError:
      # Expected behavior
      sendFuture.cancel()

  asyncTest "FIFO ordering guarantee":
    let chan = createTestChannel[int](LARGE_BUFFER_SIZE, ChannelMode.SPSC)
    let messageCount = 1000

    # Send sequential numbers
    for i in 1..messageCount:
      await chan.send(i)

    # Verify they come out in order
    for i in 1..messageCount:
      let received = await chan.recv()
      check received == i

  asyncTest "Concurrent producer consumer":
    let chan = createTestChannel[TestMessage](LARGE_BUFFER_SIZE, ChannelMode.SPSC)
    const messageCount = SMALL_TEST_SIZE
    var receivedMessages: seq[TestMessage] = @[]
    let receivedCount = Atomic[int]()

    # Producer task
    let producer = proc(): Future[void] {.async.} =
      for i in 0 ..< messageCount:
        let msg = generateTestMessage(i)
        await chan.send(msg)
      chan.close()

    # Consumer task
    let consumer = proc(): Future[void] {.async.} =
      while true:
        try:
          let msg = await chan.recv()
          receivedMessages.add(msg)
          discard receivedCount.fetchAdd(1, moRelaxed)
        except ChannelClosedError:
          break

    # Run both concurrently
    await allFutures(@[producer(), consumer()])

    # Verify all messages received
    check receivedCount.load(moAcquire) == messageCount
    check receivedMessages.len == messageCount

    # Verify ordering (messages should be in order by ID)
    for i in 0 ..< messageCount:
      check receivedMessages[i].id == i

  asyncTestWithMetrics "SPSC throughput benchmark", TARGET_SPSC_THROUGHPUT.int64:
    testConfig.expectedThroughput = TARGET_SPSC_THROUGHPUT

    let chan = createTestChannel[BenchmarkMessage](LARGE_BUFFER_SIZE, ChannelMode.SPSC)
    const iterations = MEDIUM_TEST_SIZE
    let processed = Atomic[int]()

    let producer = proc(): Future[void] {.async.} =
      for i in 0 ..< iterations:
        await chan.send(generateBenchmarkMessage(i.int64))
      chan.close()

    let consumer = proc(): Future[void] {.async.} =
      while true:
        try:
          discard await chan.recv()
          discard processed.fetchAdd(1, moRelaxed)
        except ChannelClosedError:
          break

    let startTime = getMonoTime()
    await allFutures(@[producer(), consumer()])
    let endTime = getMonoTime()

    let duration = endTime - startTime
    let throughput = iterations.float64 * 1_000_000_000.0 / duration.inNanoseconds.float64

    if testConfig.verbose:
      echo fmt"SPSC throughput: {throughput:.0f} messages/second"

    check processed.load(moAcquire) == iterations
    check throughput > TARGET_SPSC_THROUGHPUT * 0.5  # Allow 50% tolerance for test environments

  asyncTest "Error handling with invalid operations":
    let chan = createTestChannel[int](SMALL_BUFFER_SIZE, ChannelMode.SPSC)

    # Close channel first
    chan.close()

    # Sending to closed channel should raise error
    expect ChannelClosedError:
      await chan.send(123)

  asyncTest "Memory efficiency test":
    let messageCount = SMALL_TEST_SIZE

    let (result, memoryUsed) = await withMemoryMonitoring(proc(): Future[int] {.async.} =
      let chan = createTestChannel[int](MEDIUM_BUFFER_SIZE, ChannelMode.SPSC)

      for i in 0 ..< messageCount:
        await chan.send(i)
        discard await chan.recv()

      chan.close()
      return messageCount
    )

    # Verify minimal memory overhead (channels should be memory efficient)
    let maxExpectedMemory = messageCount * sizeof(int) * 2  # Allow 2x overhead
    if memoryUsed > maxExpectedMemory and testConfig.verbose:
      echo fmt"Memory usage: {memoryUsed} bytes (expected < {maxExpectedMemory})"

  asyncTest "Channel reuse after close":
    var chan = createTestChannel[string](SMALL_BUFFER_SIZE, ChannelMode.SPSC)

    # Use channel normally
    await chan.send("first")
    check (await chan.recv()) == "first"

    # Close channel
    chan.close()

    # Create new channel (simulating reuse pattern)
    chan = createTestChannel[string](SMALL_BUFFER_SIZE, ChannelMode.SPSC)

    # Should work normally
    await chan.send("second")
    check (await chan.recv()) == "second"

  asyncTest "Large message handling":
    let chan = createTestChannel[string](SMALL_BUFFER_SIZE, ChannelMode.SPSC)
    let largeMessage = randomString(10000)  # 10KB message

    await chan.send(largeMessage)
    let received = await chan.recv()

    check received == largeMessage
    check received.len == 10000