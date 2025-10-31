## Echo Server Example using nimsync
##
## Demonstrates:
## - TCP server with structured concurrency
## - Per-connection task management
## - Graceful shutdown and cleanup
## - Connection pooling and statistics

import std/[net, strformat, times, atomics]
import chronos
import ../../src/nimsync

type
  EchoServer = ref object
    socket: AsyncSocket
    port: int
    maxConnections: int
    stats: ServerStats
    shutdown: CancelScope

  ServerStats = object
    connectionsAccepted: Atomic[int64]
    messagesProcessed: Atomic[int64]
    bytesTransferred: Atomic[int64]
    activeConnections: Atomic[int64]

  ClientConnection = ref object
    socket: AsyncSocket
    id: int64
    remoteAddress: string
    connectTime: DateTime
    stats: ref ServerStats

proc newEchoServer*(port: int = 8080, maxConnections: int = 100): EchoServer =
  ## Create a new echo server
  result = EchoServer(
    socket: newAsyncSocket(),
    port: port,
    maxConnections: maxConnections,
    shutdown: initCancelScope()
  )

proc getServerStats*(server: EchoServer): tuple[
  connections: int64,
  messages: int64,
  bytes: int64,
  active: int64
] =
  ## Get current server statistics
  (
    connections: server.stats.connectionsAccepted.load(moAcquire),
    messages: server.stats.messagesProcessed.load(moAcquire),
    bytes: server.stats.bytesTransferred.load(moAcquire),
    active: server.stats.activeConnections.load(moAcquire)
  )

proc handleClient(conn: ClientConnection): Future[void] {.async.} =
  ## Handle a single client connection
  let startTime = getMonoTime()
  discard conn.stats.activeConnections.fetchAdd(1, moRelaxed)

  try:
    echo fmt"🔗 Client {conn.id} connected from {conn.remoteAddress}"

    while true:
      # Read data from client
      let data = await conn.socket.recv(1024)
      if data.len == 0:
        break  # Client disconnected

      discard conn.stats.messagesProcessed.fetchAdd(1, moRelaxed)
      discard conn.stats.bytesTransferred.fetchAdd(data.len, moRelaxed)

      # Echo the data back
      let response = fmt"ECHO: {data}"
      await conn.socket.send(response)

      # Log the interaction
      echo fmt"📨 Client {conn.id}: {data.strip()} -> {response.len} bytes"

  except CatchableError as e:
    echo fmt"❌ Client {conn.id} error: {e.msg}"
  finally:
    let endTime = getMonoTime()
    let duration = (endTime - startTime).inMilliseconds.float64 / 1000.0

    discard conn.stats.activeConnections.fetchAdd(-1, moRelaxed)
    conn.socket.close()
    echo fmt"👋 Client {conn.id} disconnected after {duration:.2f}s"

proc acceptConnections(server: EchoServer): Future[void] {.async.} =
  ## Accept incoming connections with connection limiting
  var nextClientId: int64 = 1
  let connectionSemaphore = newChannel[bool](server.maxConnections, ChannelMode.SPSC)

  # Initialize semaphore
  for i in 0 ..< server.maxConnections:
    await connectionSemaphore.send(true)

  try:
    while not server.shutdown.cancelled:
      # Wait for connection slot
      discard await connectionSemaphore.recv()

      try:
        # Accept new connection
        let (clientSocket, clientAddress) = await server.socket.acceptAddr()

        discard server.stats.connectionsAccepted.fetchAdd(1, moRelaxed)

        # Create connection object
        let conn = ClientConnection(
          socket: clientSocket,
          id: nextClientId,
          remoteAddress: clientAddress,
          connectTime: now(),
          stats: addr server.stats
        )
        nextClientId.inc

        # Handle client in separate task
        await taskGroup:
          discard g.spawn(proc(): Future[void] {.async.} =
            try:
              await handleClient(conn)
            finally:
              # Return connection slot
              await connectionSemaphore.send(true)
          )

      except CatchableError as e:
        echo fmt"❌ Accept error: {e.msg}"
        # Return connection slot on error
        await connectionSemaphore.send(true)

  except CancelledError:
    echo "🛑 Connection acceptance cancelled"
  finally:
    connectionSemaphore.close()

proc statsReporter(server: EchoServer): Future[void] {.async.} =
  ## Report server statistics periodically
  while not server.shutdown.cancelled:
    try:
      await chronos.sleepAsync(5.seconds)

      let stats = server.getServerStats()
      echo fmt"📊 Stats: {stats.active} active, {stats.connections} total connections, {stats.messages} messages, {stats.bytes} bytes"

    except CancelledError:
      break
    except CatchableError as e:
      echo fmt"❌ Stats reporter error: {e.msg}"

proc start*(server: EchoServer): Future[void] {.async.} =
  ## Start the echo server
  echo fmt"🚀 Starting echo server on port {server.port}..."

  try:
    # Bind and listen
    server.socket.setSockOpt(OptReuseAddr, true)
    server.socket.bindAddr(Port(server.port))
    server.socket.listen()

    echo fmt"✅ Server listening on port {server.port}"
    echo fmt"📈 Max connections: {server.maxConnections}"

    # Use TaskGroup for structured concurrency
    await taskGroup:
      # Accept connections
      discard g.spawn(proc(): Future[void] {.async.} =
        await server.acceptConnections()
      )

      # Statistics reporting
      discard g.spawn(proc(): Future[void] {.async.} =
        await server.statsReporter()
      )

      # Wait for shutdown signal
      discard g.spawn(proc(): Future[void] {.async.} =
        while not server.shutdown.cancelled:
          await chronos.sleepAsync(100.milliseconds)
      )

  except CatchableError as e:
    echo fmt"❌ Server error: {e.msg}"
  finally:
    server.socket.close()
    echo "🛑 Echo server stopped"

proc shutdown*(server: EchoServer): Future[void] {.async.} =
  ## Gracefully shutdown the server
  echo "🛑 Initiating server shutdown..."
  server.shutdown.cancel()

  # Give active connections time to finish
  await chronos.sleepAsync(1.seconds)

  let stats = server.getServerStats()
  if stats.active > 0:
    echo fmt"⏳ Waiting for {stats.active} active connections to finish..."

    # Wait up to 10 seconds for graceful shutdown
    var waited = 0
    while stats.active > 0 and waited < 100:
      await chronos.sleepAsync(100.milliseconds)
      waited.inc

    let finalStats = server.getServerStats()
    if finalStats.active > 0:
      echo fmt"⚠️  Force closing {finalStats.active} remaining connections"

proc testClient*(port: int = 8080, messages: int = 5): Future[void] {.async.} =
  ## Simple test client to demonstrate the server
  echo fmt"🧪 Testing echo server on port {port}..."

  try:
    let socket = newAsyncSocket()
    await socket.connect("localhost", Port(port))

    echo "✅ Connected to server"

    for i in 1..messages:
      let message = fmt"Hello from client #{i}"
      await socket.send(message)

      let response = await socket.recv(1024)
      echo fmt"📨 Sent: {message}"
      echo fmt"📬 Received: {response}"

      await chronos.sleepAsync(500.milliseconds)

    socket.close()
    echo "👋 Client disconnected"

  except CatchableError as e:
    echo fmt"❌ Client error: {e.msg}"

proc loadTest*(port: int = 8080, clients: int = 10, messagesPerClient: int = 3): Future[void] {.async.} =
  ## Load test the server with multiple concurrent clients
  echo fmt"🔥 Load testing with {clients} concurrent clients..."

  await taskGroup:
    for i in 1..clients:
      discard g.spawn(proc(): Future[void] {.async.} =
        try:
          let socket = newAsyncSocket()
          await socket.connect("localhost", Port(port))

          for j in 1..messagesPerClient:
            let message = fmt"Client-{i} message-{j}"
            await socket.send(message)
            discard await socket.recv(1024)
            await chronos.sleepAsync(100.milliseconds)

          socket.close()

        except CatchableError as e:
          echo fmt"❌ Load test client {i} error: {e.msg}"
      )

  echo "✅ Load test completed"

proc main() {.async.} =
  echo "🌐 Echo Server Example with nimsync"
  echo "===================================="

  let server = newEchoServer(port = 8080, maxConnections = 50)

  # Start server in background
  await taskGroup:
    discard g.spawn(proc(): Future[void] {.async.} =
      await server.start()
    )

    # Give server time to start
    discard g.spawn(proc(): Future[void] {.async.} =
      await chronos.sleepAsync(1.seconds)

      # Test the server
      await testClient(8080, 3)

      await chronos.sleepAsync(1.seconds)

      # Load test
      await loadTest(8080, 5, 2)

      await chronos.sleepAsync(2.seconds)

      # Final stats
      let stats = server.getServerStats()
      echo fmt"\n📊 Final Stats:"
      echo fmt"  Total connections: {stats.connections}"
      echo fmt"  Messages processed: {stats.messages}"
      echo fmt"  Bytes transferred: {stats.bytes}"
      echo fmt"  Active connections: {stats.active}"

      # Shutdown server
      await server.shutdown()
    )

  echo "\n✅ Echo server example completed!"

when isMainModule:
  waitFor main()