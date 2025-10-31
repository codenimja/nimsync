## Test suite for channel select operations

import std/[unittest, strformat]
import chronos
import nimsync

suite "Channel Select Operations":
  test "Basic select receive operation":
    proc testBasicSelectReceive() {.async.} =
      var ch1 = newChannel[int](10, ChannelMode.SPSC)
      var ch2 = newChannel[int](10, ChannelMode.SPSC)

      # Send to first channel (non-blocking)
      discard ch1.spsc.trySend(42)

      # Create select operation
      var selectBuilder = initSelect[int]()
      selectBuilder = selectBuilder.recv(ch1).recv(ch2).timeout(1000)

      let result = await selectBuilder.run()

      check(not result.isTimeout)
      check(result.caseIndex == 0)  # First case (ch1)
      check(result.value == 42)

    waitFor testBasicSelectReceive()

  test "Basic select send operation":
    proc testBasicSelectSend() {.async.} =
      var ch1 = newChannel[int](1, ChannelMode.SPSC)
      var ch2 = newChannel[int](1, ChannelMode.SPSC)

      # Fill first channel (non-blocking)
      discard ch1.spsc.trySend(1)

      # Second channel should be available for sending
      var selectBuilder = initSelect[int]()
      selectBuilder = selectBuilder.send(ch1, 99).send(ch2, 42).timeout(1000)

      let result = await selectBuilder.run()

      check(not result.isTimeout)
      check(result.caseIndex == 1)  # Second case (ch2)

      # Verify the value was sent (non-blocking)
      var received: int
      check(ch2.spsc.tryReceive(received))
      check(received == 42)

    waitFor testBasicSelectSend()

  test "Select timeout":
    proc testSelectTimeout() {.async.} =
      var ch1 = newChannel[int](10, ChannelMode.SPSC)
      var ch2 = newChannel[int](10, ChannelMode.SPSC)

      # No data in channels
      var selectBuilder = initSelect[int]()
      selectBuilder = selectBuilder.recv(ch1).recv(ch2).timeout(100)  # Short timeout

      let result = await selectBuilder.run()

      check(result.isTimeout)
      check(result.caseIndex == -1)

    waitFor testSelectTimeout()

  test "Select immediate operation":
    proc testSelectImmediate() {.async.} =
      var ch1 = newChannel[int](10, ChannelMode.SPSC)
      var ch2 = newChannel[int](10, ChannelMode.SPSC)

      # Send to second channel (non-blocking)
      discard ch2.spsc.trySend(123)

      # Create cases array
      var cases = [
        SelectCase[int](channel: addr ch1, isRecv: true),
        SelectCase[int](channel: addr ch2, isRecv: true)
      ]

      let result = selectImmediate(cases)

      check(result.caseIndex == 1)  # Second case
      check(result.value == 123)

    waitFor testSelectImmediate()

  test "Fair select operation":
    proc testFairSelect() {.async.} =
      var ch1 = newChannel[int](10, ChannelMode.SPSC)
      var ch2 = newChannel[int](10, ChannelMode.SPSC)

      # Send to both channels (non-blocking)
      discard ch1.spsc.trySend(1)
      discard ch2.spsc.trySend(2)

      var cases = [
        SelectCase[int](channel: addr ch1, isRecv: true),
        SelectCase[int](channel: addr ch2, isRecv: true)
      ]

      var startIndex = 0

      # First call should select first ready case
      let result1 = fairSelect(cases, startIndex)
      check(result1.caseIndex >= 0)

      # Add more data (non-blocking)
      discard ch1.spsc.trySend(3)
      discard ch2.spsc.trySend(4)

      # Next call should start from next index (fair rotation)
      let result2 = fairSelect(cases, startIndex)
      check(result2.caseIndex >= 0)

      # Verify startIndex was updated
      check(startIndex != 0)

    waitFor testFairSelect()

  test "Select with mixed send/receive":
    proc testMixedSelect() {.async.} =
      var sendCh = newChannel[int](1, ChannelMode.SPSC)
      var recvCh = newChannel[int](10, ChannelMode.SPSC)

      # Prepare receive channel (non-blocking)
      discard recvCh.spsc.trySend(999)

      var selectBuilder = initSelect[int]()
      selectBuilder = selectBuilder.send(sendCh, 42).recv(recvCh)  # Should succeed

      let result = await selectBuilder.run()

      check(not result.isTimeout)
      check(result.caseIndex >= 0)

      # One of the operations should have succeeded
      if result.caseIndex == 0:
        # Send succeeded, verify it (non-blocking)
        var sent: int
        check(sendCh.spsc.tryReceive(sent))
        check(sent == 42)
      else:
        # Receive succeeded
        check(result.value == 999)

    waitFor testMixedSelect()

  test "Select performance":
    proc testSelectPerformance() {.async.} =
      var ch = newChannel[int](1000, ChannelMode.SPSC)

      # Fill channel with data (non-blocking)
      for i in 1..100:
        discard ch.spsc.trySend(i)

      let startTime = getMonoTime()

      # Perform many select operations
      for i in 1..100:
        var selectBuilder = initSelect[int]()
        selectBuilder = selectBuilder.recv(ch).timeout(1000)

        let result = await selectBuilder.run()
        check(not result.isTimeout)
        check(result.value == i)

      let elapsed = getMonoTime() - startTime
      let microseconds = elapsed.inMicroseconds

      echo fmt"100 select operations took {microseconds} microseconds"
      echo fmt"Average: {microseconds / 100} microseconds per select"

      # Performance target: < 10ms for 100 operations
      check(microseconds < 10_000)

    waitFor testSelectPerformance()

  test "Select with channel closing":
    proc testSelectWithClosing() {.async.} =
      var ch1 = newChannel[int](10, ChannelMode.SPSC)
      var ch2 = newChannel[int](10, ChannelMode.SPSC)

      # Close first channel
      ch1.close()

      # Put data in second channel (non-blocking)
      discard ch2.spsc.trySend(42)

      var selectBuilder = initSelect[int]()
      selectBuilder = selectBuilder.recv(ch1).recv(ch2).timeout(1000)  # ch1 closed, ch2 should succeed

      # Should select the open channel
      let result = await selectBuilder.run()

      check(not result.isTimeout)
      check(result.caseIndex == 1)
      check(result.value == 42)

    waitFor testSelectWithClosing()

echo "Select operation tests completed!"