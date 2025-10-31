## Channels and Select Example
##
## Demonstrates bounded channels with select operations for fair
## scheduling across multiple channel operations and timeouts.
##
## This is a realistic example showing the planned API for channels
## and select operations in nimsync.

import std/[times, strformat]
import chronos
import nimsync/[channels, group, cancel]

type
  Message = object
    id: int
    data: string
    timestamp: Time

proc producer(name: string, ch: var Channel[Message], count: int) {.async.} =
  ## Producer sends messages to a channel
  echo fmt"Producer {name} starting..."

  for i in 1..count:
    let msg = Message(
      id: i,
      data: fmt"{name}-message-{i}",
      timestamp: getTime()
    )

    # In the real implementation, this would be awaitable and respect backpressure
    ch.send(msg)
    echo fmt"Producer {name} sent: {msg.data}"

    # Simulate some work
    await sleepAsync(100.milliseconds)

  echo fmt"Producer {name} finished"

proc consumer(name: string, ch: var Channel[Message]) {.async.} =
  ## Consumer receives messages from a channel
  echo fmt"Consumer {name} starting..."

  var received = 0
  while received < 10: # Arbitrary limit for demo
    var msg: Message

    # In the real implementation, tryRecv would be replaced with awaitable recv
    if ch.tryRecv(msg):
      received += 1
      echo fmt"Consumer {name} received: {msg.data} (id: {msg.id})"
    else:
      # Simulate waiting for messages
      await sleepAsync(50.milliseconds)

  echo fmt"Consumer {name} finished"

proc selectExample() {.async.} =
  ## Demonstrates select operation across multiple channels and timeouts
  echo "=== Select Example ==="

  var ch1 = newChannel[Message](capacity = 10)
  var ch2 = newChannel[Message](capacity = 10)

  # In the real implementation, this would use proper select syntax:
  # select:
  #   case msg <- ch1:
  #     echo "Received from ch1: ", msg.data
  #   case msg <- ch2:
  #     echo "Received from ch2: ", msg.data
  #   case _ <- timer(1.seconds):
  #     echo "Timeout!"

  # For now, simulate select behavior
  echo "Simulating select across multiple channels..."

  # Send to both channels
  ch1.send(Message(id: 1, data: "ch1-msg", timestamp: getTime()))
  ch2.send(Message(id: 2, data: "ch2-msg", timestamp: getTime()))

  # Try to receive from either (simplified simulation)
  var msg: Message
  if ch1.tryRecv(msg):
    echo fmt"Select received from ch1: {msg.data}"
  elif ch2.tryRecv(msg):
    echo fmt"Select received from ch2: {msg.data}"
  else:
    echo "Select: no messages available"

proc main() {.async.} =
  echo "=== Channels and Select Example ==="
  echo "Demonstrating planned API for bounded channels and select operations"
  echo ""

  # Create bounded channel
  var messageChannel = newChannel[Message](capacity = 5)
  echo fmt"Created bounded channel with capacity: {messageChannel.capacity}"

  # This will use TaskGroup in the real implementation:
  # await taskGroup(proc(g: var TaskGroup) {.async.} =
  #   discard g.spawn(producer("A", messageChannel, 5))
  #   discard g.spawn(producer("B", messageChannel, 5))
  #   discard g.spawn(consumer("X", messageChannel))
  #   discard g.spawn(consumer("Y", messageChannel))
  # )

  # For now, run sequentially for demonstration
  echo "\n--- Running Producers and Consumers ---"

  # Simulate concurrent operations
  let futures = @[
    producer("A", messageChannel, 3),
    producer("B", messageChannel, 3),
    consumer("X", messageChannel),
    consumer("Y", messageChannel)
  ]

  # Wait for some operations (simplified)
  await sleepAsync(2.seconds)

  echo "\n--- Select Operations ---"
  await selectExample()

  echo "\nExample completed!"

when isMainModule:
  waitFor main()