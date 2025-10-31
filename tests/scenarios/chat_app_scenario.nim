## Chat Application Scenario Test
## Demonstrates nimsync channels for message passing in a chat application
## Mock data simulates multiple users sending messages concurrently

import nimsync
import std/[random, strutils, times]

type
  ChatMessage = object
    userId: int
    username: string
    content: string
    timestamp: Time

  User = object
    id: int
    name: string

proc generateMockUsers(count: int): seq[User] =
  for i in 1..count:
    result.add User(id: i, name: "User" & $i)

proc generateMockMessage(user: User): ChatMessage =
  let messages = [
    "Hello everyone!",
    "How's the weather?",
    "Working on some async code",
    "Nim is awesome",
    "Anyone up for coffee?",
    "Just finished a task",
    "Need help with channels",
    "Great work on the project!",
    "Time for a break",
    "See you later!"
  ]
  ChatMessage(
    userId: user.id,
    username: user.name,
    content: sample(messages),
    timestamp: getTime()
  )

proc chatServer(channel: Channel[ChatMessage], duration: Duration) {.async.} =
  ## Simulate chat server processing messages
  let endTime = getTime() + duration
  var messageCount = 0

  while getTime() < endTime:
    let msg = await channel.recv()
    echo &"[{msg.timestamp.format(\"HH:mm:ss\")}] {msg.username}: {msg.content}"
    messageCount += 1
    await sleepAsync(10.milliseconds)  # Simulate processing delay

  echo &"\nChat server processed {messageCount} messages"

proc chatUser(user: User, channel: Channel[ChatMessage], messageCount: int) {.async.} =
  ## Simulate a user sending messages
  for i in 1..messageCount:
    let msg = generateMockMessage(user)
    await channel.send(msg)
    await sleepAsync(rand(100..500).milliseconds)  # Random delay between messages

proc chatApplicationScenario*() {.async.} =
  ## Main test scenario: Multi-user chat application
  echo "Starting chat application scenario..."

  # Create a channel for message passing
  var chatChannel = newChannel[ChatMessage](100, MPMC)

  # Generate mock users
  let users = generateMockUsers(5)

  # Run chat server and users concurrently
  await taskGroup:
    # Start chat server
    discard g.spawn chatServer(chatChannel, 3.seconds)

    # Start user clients
    for user in users:
      proc startUser(user: User) {.async.} =
        await chatUser(user, chatChannel, rand(3..8))  # Each user sends 3-8 messages
      discard g.spawn startUser(user)

  echo "Chat application scenario completed."

when isMainModule:
  waitFor chatApplicationScenario()