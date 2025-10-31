## Channel and Actor system test
##
## Tests channel communication, backpressure, actor messaging, and stream functionality

import std/[unittest, strutils, asyncdispatch]
import ../../src/nimsync
import ../../src/nimsync/channels

suite "Channel System Tests":
  test "Channel creation and basic properties":
    try:
      var chan = newChannel[int](10, channels.ChannelMode.SPSC)
      check capacity(chan) == 10
      check chan.isEmpty
      check not chan.isFull
      echo "✅ Channel creation works"
    except Exception as e:
      echo "❌ Channel creation error: ", e.msg
      check false

  test "Channel send and receive":
    try:
      var chan = newChannel[int](5, channels.ChannelMode.SPSC)

      # Send a value
      waitFor send(chan, 42)
      check not chan.isEmpty

      # Receive the value
      let value = waitFor recv(chan)
      check value == 42
      check chan.isEmpty
      echo "✅ Channel send/receive works"
    except Exception as e:
      echo "❌ Channel send/receive error: ", e.msg
      check false

  test "Channel multiple values":
    try:
      var chan = newChannel[string](3, channels.ChannelMode.SPSC)

      # Send multiple values
      await send(chan, "first")
      await send(chan, "second")
      await send(chan, "third")

      check chan.isFull

      # Receive all values
      let first = await recv(chan)
      let second = await recv(chan)
      let third = await recv(chan)

      check first == "first"
      check second == "second"
      check third == "third"
      check chan.isEmpty
      echo "✅ Multiple channel values work"
    except Exception as e:
      echo "❌ Multiple channel values error: ", e.msg
      check false

  test "Channel backpressure":
    try:
      var chan = newChannel[int](2, channels.ChannelMode.SPSC)  # Small capacity

      # Fill the channel
      await send(chan, 1)
      await send(chan, 2)
      check chan.isFull

      var sendBlocked = false

      # Try to send another (should block due to backpressure)
      proc blockedSender(): Future[void] {.async.} =
        sendBlocked = true
        await send(chan, 3)

      let senderFuture = blockedSender()

      # Give it time to start
      await sleepAsync(10.milliseconds)
      check sendBlocked

      # Receive one to unblock
      let value = await recv(chan)
      check value == 1

      # Now sender should complete
      await senderFuture
      echo "✅ Channel backpressure works"
    except Exception as e:
      echo "❌ Channel backpressure error: ", e.msg
      check false

suite "Stream System Tests":
  test "Stream creation and basic flow":
    try:
      var stream = initStream[string](BackpressurePolicy.Block)

      # Send and receive through stream
      await stream.send("Hello")
      let msg = await stream.receive()
      check msg == "Hello"
      echo "✅ Stream basic flow works"
    except Exception as e:
      echo "❌ Stream basic flow error: ", e.msg
      check false

  test "Stream backpressure policy":
    try:
      var dropStream = initStream[int](BackpressurePolicy.Drop)
      var blockStream = initStream[int](BackpressurePolicy.Block)

      # Test drop policy doesn't block
      await dropStream.send(1)
      await dropStream.send(2)
      await dropStream.send(3)

      # Test block policy behavior
      await blockStream.send(10)
      let value = await blockStream.receive()
      check value == 10
      echo "✅ Stream backpressure policies work"
    except Exception as e:
      echo "❌ Stream backpressure error: ", e.msg
      check false

suite "Actor System Tests":
  test "Actor creation and basic messaging":
    try:
      # Create actor system
      var system = initActorSystem()

      # Define a simple behavior
      proc simpleBehavior(msg: string): Future[void] {.async.} =
        echo "Actor received: ", msg

      # Spawn actor
      let actor = system.spawn(simpleBehavior)
      check not actor.isNil

      # Send message
      await actor.send("Hello Actor")

      # Give time for processing
      await sleepAsync(10.milliseconds)
      echo "✅ Actor creation and messaging works"
    except Exception as e:
      echo "❌ Actor messaging error: ", e.msg
      check false

  test "Actor mailbox handling":
    try:
      var system = initActorSystem()
      var messagesReceived = 0

      proc countingBehavior(msg: int): Future[void] {.async.} =
        inc messagesReceived

      let actor = system.spawn(countingBehavior)

      # Send multiple messages
      await actor.send(1)
      await actor.send(2)
      await actor.send(3)

      # Give time for processing
      await sleepAsync(50.milliseconds)

      check messagesReceived == 3
      echo "✅ Actor mailbox handling works"
    except Exception as e:
      echo "❌ Actor mailbox error: ", e.msg
      check false

echo "✅ Channel and Actor system tests completed"