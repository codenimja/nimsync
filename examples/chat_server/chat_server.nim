## Chat Server Example using nimsync
##
## Demonstrates:
## - Multi-room chat server with channels
## - Actor-based client management
## - Message broadcasting and routing
## - Real-time communication patterns

import std/[net, strformat, times, tables, json, strutils, sequtils]
import chronos
import ../../src/nimsync

type
  ChatMessage = object
    sender: string
    room: string
    content: string
    timestamp: DateTime
    messageType: MessageType

  MessageType = enum
    TextMessage = "text"
    JoinMessage = "join"
    LeaveMessage = "leave"
    SystemMessage = "system"

  ChatRoom = ref object
    name: string
    clients: seq[ChatClient]
    messageHistory: seq[ChatMessage]
    messageChannel: Channel[ChatMessage]

  ChatClient = ref object
    id: string
    username: string
    socket: AsyncSocket
    currentRoom: string
    joinTime: DateTime
    messagesSent: int

  ChatServer = ref object
    rooms: Table[string, ChatRoom]
    clients: Table[string, ChatClient]
    globalChannel: Channel[ChatMessage]
    shutdown: CancelScope

proc newChatMessage(sender, room, content: string, msgType: MessageType = TextMessage): ChatMessage =
  ChatMessage(
    sender: sender,
    room: room,
    content: content,
    timestamp: now(),
    messageType: msgType
  )

proc `$`(msg: ChatMessage): string =
  fmt"[{msg.timestamp.format(\"HH:mm:ss\")}] {msg.sender}: {msg.content}"

proc toJson(msg: ChatMessage): string =
  let jsonObj = %*{
    "sender": msg.sender,
    "room": msg.room,
    "content": msg.content,
    "timestamp": $msg.timestamp,
    "type": $msg.messageType
  }
  $jsonObj

proc newChatRoom(name: string): ChatRoom =
  ChatRoom(
    name: name,
    clients: @[],
    messageHistory: @[],
    messageChannel: newChannel[ChatMessage](100, ChannelMode.MPMC)
  )

proc newChatServer(): ChatServer =
  result = ChatServer(
    rooms: initTable[string, ChatRoom](),
    clients: initTable[string, ChatClient](),
    globalChannel: newChannel[ChatMessage](1000, ChannelMode.MPMC),
    shutdown: initCancelScope()
  )

  # Create default rooms
  result.rooms["general"] = newChatRoom("general")
  result.rooms["random"] = newChatRoom("random")

proc addClient(room: ChatRoom, client: ChatClient) =
  room.clients.add(client)
  client.currentRoom = room.name

  let joinMsg = newChatMessage(
    "System",
    room.name,
    fmt"{client.username} joined the room",
    JoinMessage
  )
  room.messageHistory.add(joinMsg)

proc removeClient(room: ChatRoom, client: ChatClient) =
  room.clients = room.clients.filterIt(it.id != client.id)

  let leaveMsg = newChatMessage(
    "System",
    room.name,
    fmt"{client.username} left the room",
    LeaveMessage
  )
  room.messageHistory.add(leaveMsg)

proc broadcastToRoom(room: ChatRoom, message: ChatMessage): Future[void] {.async.} =
  ## Broadcast message to all clients in room
  await room.messageChannel.send(message)

proc handleRoomMessages(room: ChatRoom): Future[void] {.async.} =
  ## Handle message broadcasting for a specific room
  while not room.messageChannel.closed:
    try:
      let message = await room.messageChannel.recv()
      room.messageHistory.add(message)

      echo fmt"📢 Broadcasting to {room.name}: {message}"

      # Send to all clients in room
      var disconnectedClients: seq[int] = @[]

      for i, client in room.clients:
        try:
          await client.socket.send(message.toJson & "\n")
        except CatchableError:
          disconnectedClients.add(i)

      # Remove disconnected clients
      for i in disconnectedClients.reversed:
        echo fmt"🔌 Removing disconnected client: {room.clients[i].username}"
        room.clients.delete(i)

    except ChannelClosedError:
      break
    except CatchableError as e:
      echo fmt"❌ Room {room.name} broadcast error: {e.msg}"

proc handleClientMessages(server: ChatServer, client: ChatClient): Future[void] {.async.} =
  ## Handle messages from a specific client
  try:
    while true:
      let rawData = await client.socket.recvLine()
      if rawData.len == 0:
        break

      try:
        let data = parseJson(rawData)
        let command = data["command"].getStr()

        case command:
        of "join":
          let roomName = data["room"].getStr()
          if roomName in server.rooms:
            # Leave current room
            if client.currentRoom.len > 0:
              server.rooms[client.currentRoom].removeClient(client)

            # Join new room
            server.rooms[roomName].addClient(client)
            echo fmt"🚪 {client.username} joined room: {roomName}"

            # Send room history
            let room = server.rooms[roomName]
            for msg in room.messageHistory[max(0, room.messageHistory.len - 10)..^1]:
              await client.socket.send(msg.toJson & "\n")

        of "message":
          let content = data["content"].getStr()
          if client.currentRoom.len > 0:
            let message = newChatMessage(client.username, client.currentRoom, content)
            await server.rooms[client.currentRoom].broadcastToRoom(message)
            client.messagesSent.inc

        of "list_rooms":
          let rooms = toSeq(server.rooms.keys)
          let response = %*{
            "type": "room_list",
            "rooms": rooms
          }
          await client.socket.send($response & "\n")

        of "list_users":
          if client.currentRoom.len > 0:
            let users = server.rooms[client.currentRoom].clients.mapIt(it.username)
            let response = %*{
              "type": "user_list",
              "users": users,
              "room": client.currentRoom
            }
            await client.socket.send($response & "\n")

        else:
          echo fmt"❓ Unknown command from {client.username}: {command}"

      except JsonParsingError:
        echo fmt"❌ Invalid JSON from {client.username}: {rawData}"

  except CatchableError as e:
    echo fmt"❌ Client {client.username} error: {e.msg}"
  finally:
    # Cleanup
    if client.currentRoom.len > 0:
      server.rooms[client.currentRoom].removeClient(client)
    server.clients.del(client.id)
    client.socket.close()

    let duration = (now() - client.joinTime).inSeconds
    echo fmt"👋 Client {client.username} disconnected after {duration}s ({client.messagesSent} messages sent)"

proc acceptClients(server: ChatServer, serverSocket: AsyncSocket): Future[void] {.async.} =
  ## Accept and handle new client connections
  var clientIdCounter = 0

  while not server.shutdown.cancelled:
    try:
      let (clientSocket, address) = await serverSocket.acceptAddr()
      clientIdCounter.inc

      echo fmt"🔗 New connection from {address}"

      # Handshake - get username
      await clientSocket.send(%*{"type": "handshake", "message": "Please provide username"} & "\n")
      let handshakeData = await clientSocket.recvLine()

      try:
        let handshake = parseJson(handshakeData)
        let username = handshake["username"].getStr()

        # Create client
        let client = ChatClient(
          id: fmt"client_{clientIdCounter}",
          username: username,
          socket: clientSocket,
          currentRoom: "",
          joinTime: now(),
          messagesSent: 0
        )

        server.clients[client.id] = client
        echo fmt"👤 Client registered: {username} ({client.id})"

        # Handle client in separate task
        await taskGroup:
          discard g.spawn(proc(): Future[void] {.async.} =
            await server.handleClientMessages(client)
          )

      except JsonParsingError:
        echo "❌ Invalid handshake, closing connection"
        clientSocket.close()

    except CancelledError:
      break
    except CatchableError as e:
      echo fmt"❌ Accept error: {e.msg}"

proc start*(server: ChatServer, port: int = 9000): Future[void] {.async.} =
  ## Start the chat server
  echo fmt"💬 Starting chat server on port {port}..."

  let serverSocket = newAsyncSocket()
  try:
    serverSocket.setSockOpt(OptReuseAddr, true)
    serverSocket.bindAddr(Port(port))
    serverSocket.listen()

    echo fmt"✅ Chat server listening on port {port}"
    echo fmt"🏠 Available rooms: {toSeq(server.rooms.keys)}"

    await taskGroup:
      # Handle room message broadcasting
      for room in server.rooms.values:
        discard g.spawn(proc(): Future[void] {.async.} =
          await room.handleRoomMessages()
        )

      # Accept client connections
      discard g.spawn(proc(): Future[void] {.async.} =
        await server.acceptClients(serverSocket)
      )

      # Server stats
      discard g.spawn(proc(): Future[void] {.async.} =
        while not server.shutdown.cancelled:
          await chronos.sleepAsync(10.seconds)
          echo fmt"📊 Stats: {server.clients.len} clients, {server.rooms.len} rooms"
          for roomName, room in server.rooms:
            echo fmt"  📱 {roomName}: {room.clients.len} clients, {room.messageHistory.len} messages"
      )

  except CatchableError as e:
    echo fmt"❌ Server error: {e.msg}"
  finally:
    serverSocket.close()
    echo "🛑 Chat server stopped"

proc shutdown*(server: ChatServer): Future[void] {.async.} =
  ## Gracefully shutdown the chat server
  echo "🛑 Shutting down chat server..."
  server.shutdown.cancel()

  # Close all room channels
  for room in server.rooms.values:
    room.messageChannel.close()

  await chronos.sleepAsync(1.seconds)

proc testClient*(port: int = 9000, username: string = "TestUser"): Future[void] {.async.} =
  ## Simple test client for the chat server
  echo fmt"🧪 Testing chat server as {username}..."

  try:
    let socket = newAsyncSocket()
    await socket.connect("localhost", Port(port))

    # Handshake
    let handshake = await socket.recvLine()
    echo fmt"📨 Handshake: {handshake}"

    await socket.send(%*{"username": username} & "\n")

    # Join general room
    await socket.send(%*{"command": "join", "room": "general"} & "\n")
    await chronos.sleepAsync(500.milliseconds)

    # Send some messages
    for i in 1..3:
      await socket.send(%*{"command": "message", "content": fmt"Hello from {username} #{i}"} & "\n")
      await chronos.sleepAsync(1.seconds)

    # List users
    await socket.send(%*{"command": "list_users"} & "\n")
    await chronos.sleepAsync(500.milliseconds)

    socket.close()
    echo fmt"👋 {username} disconnected"

  except CatchableError as e:
    echo fmt"❌ Test client {username} error: {e.msg}"

proc main() {.async.} =
  echo "💬 Chat Server Example with nimsync"
  echo "===================================="

  let server = newChatServer()

  await taskGroup:
    # Start server
    discard g.spawn(proc(): Future[void] {.async.} =
      await server.start(9000)
    )

    # Test clients
    discard g.spawn(proc(): Future[void] {.async.} =
      await chronos.sleepAsync(1.seconds)

      # Spawn multiple test clients
      await taskGroup:
        discard g.spawn(testClient(9000, "Alice"))
        discard g.spawn(testClient(9000, "Bob"))
        discard g.spawn(testClient(9000, "Charlie"))

      await chronos.sleepAsync(3.seconds)
      await server.shutdown()
    )

  echo "\n✅ Chat server example completed!"

when isMainModule:
  waitFor main()