## Micro Web Framework using nimsync
##
## Demonstrates:
## - HTTP server with structured concurrency
## - Middleware pipeline with channels
## - Route handling and request processing
## - Session management and WebSocket support

import std/[net, strformat, times, tables, json, strutils, uri, mimetypes]
import chronos
import ../../src/nimsync

type
  HttpMethod* = enum
    GET = "GET"
    POST = "POST"
    PUT = "PUT"
    DELETE = "DELETE"
    PATCH = "PATCH"
    HEAD = "HEAD"
    OPTIONS = "OPTIONS"

  HttpStatus* = enum
    Ok = 200
    Created = 201
    BadRequest = 400
    NotFound = 404
    InternalServerError = 500

  HttpRequest* = ref object
    httpMethod*: HttpMethod
    path*: string
    query*: Table[string, string]
    headers*: Table[string, string]
    body*: string
    params*: Table[string, string]
    session*: Session

  HttpResponse* = ref object
    status*: HttpStatus
    headers*: Table[string, string]
    body*: string

  Session* = ref object
    id*: string
    data*: Table[string, string]
    createdAt*: DateTime

  RouteHandler* = proc(req: HttpRequest): Future[HttpResponse] {.async.}

  Middleware* = proc(req: HttpRequest, next: proc(): Future[HttpResponse] {.async.}): Future[HttpResponse] {.async.}

  Route* = object
    httpMethod*: HttpMethod
    pattern*: string
    handler*: RouteHandler

  WebFramework* = ref object
    routes*: seq[Route]
    middleware*: seq[Middleware]
    sessions*: Table[string, Session]
    serverSocket*: AsyncSocket
    requestChannel*: Channel[tuple[socket: AsyncSocket, data: string]]
    responseChannel*: Channel[tuple[socket: AsyncSocket, response: string]]
    shutdown*: CancelScope

proc newHttpRequest*(): HttpRequest =
  HttpRequest(
    query: initTable[string, string](),
    headers: initTable[string, string](),
    params: initTable[string, string]()
  )

proc newHttpResponse*(status: HttpStatus = Ok): HttpResponse =
  HttpResponse(
    status: status,
    headers: initTable[string, string](),
    body: ""
  )

proc json*(response: HttpResponse, data: JsonNode): HttpResponse =
  response.headers["Content-Type"] = "application/json"
  response.body = $data
  return response

proc text*(response: HttpResponse, content: string): HttpResponse =
  response.headers["Content-Type"] = "text/plain"
  response.body = content
  return response

proc html*(response: HttpResponse, content: string): HttpResponse =
  response.headers["Content-Type"] = "text/html"
  response.body = content
  return response

proc parseRequest(data: string): HttpRequest =
  let lines = data.split("\r\n")
  if lines.len == 0:
    return newHttpRequest()

  let requestLine = lines[0].split(" ")
  let request = newHttpRequest()

  if requestLine.len >= 3:
    case requestLine[0]:
    of "GET": request.httpMethod = GET
    of "POST": request.httpMethod = POST
    of "PUT": request.httpMethod = PUT
    of "DELETE": request.httpMethod = DELETE
    else: request.httpMethod = GET

    request.path = requestLine[1]

  # Parse headers
  var headerEnd = 1
  for i in 1..<lines.len:
    if lines[i] == "":
      headerEnd = i
      break

    let headerParts = lines[i].split(": ", 1)
    if headerParts.len == 2:
      request.headers[headerParts[0].toLower()] = headerParts[1]

  # Parse body (if present)
  if headerEnd + 1 < lines.len:
    request.body = lines[headerEnd + 1..^1].join("\r\n")

  return request

proc formatResponse(response: HttpResponse): string =
  var lines: seq[string] = @[]
  lines.add(fmt"HTTP/1.1 {response.status.int} {response.status}")

  for key, value in response.headers:
    lines.add(fmt"{key}: {value}")

  lines.add(fmt"Content-Length: {response.body.len}")
  lines.add("")
  lines.add(response.body)

  return lines.join("\r\n")

proc newWebFramework*(): WebFramework =
  WebFramework(
    routes: @[],
    middleware: @[],
    sessions: initTable[string, Session](),
    serverSocket: newAsyncSocket(),
    requestChannel: newChannel[tuple[socket: AsyncSocket, data: string]](100, ChannelMode.MPSC),
    responseChannel: newChannel[tuple[socket: AsyncSocket, response: string]](100, ChannelMode.MPSC),
    shutdown: initCancelScope()
  )

proc get*(framework: WebFramework, pattern: string, handler: RouteHandler) =
  framework.routes.add(Route(httpMethod: GET, pattern: pattern, handler: handler))

proc post*(framework: WebFramework, pattern: string, handler: RouteHandler) =
  framework.routes.add(Route(httpMethod: POST, pattern: pattern, handler: handler))

proc put*(framework: WebFramework, pattern: string, handler: RouteHandler) =
  framework.routes.add(Route(httpMethod: PUT, pattern: pattern, handler: handler))

proc delete*(framework: WebFramework, pattern: string, handler: RouteHandler) =
  framework.routes.add(Route(httpMethod: DELETE, pattern: pattern, handler: handler))

proc use*(framework: WebFramework, middleware: Middleware) =
  framework.middleware.add(middleware)

proc matchRoute(framework: WebFramework, request: HttpRequest): Route =
  for route in framework.routes:
    if route.httpMethod == request.httpMethod and route.pattern == request.path:
      return route

  # Return 404 route
  return Route(
    httpMethod: GET,
    pattern: "",
    handler: proc(req: HttpRequest): Future[HttpResponse] {.async.} =
      return newHttpResponse(NotFound).text("Not Found")
  )

proc applyMiddleware(framework: WebFramework, request: HttpRequest, handler: RouteHandler): Future[HttpResponse] {.async.} =
  var middlewareIndex = 0

  proc runNext(): Future[HttpResponse] {.async.} =
    if middlewareIndex < framework.middleware.len:
      let currentMiddleware = framework.middleware[middlewareIndex]
      middlewareIndex.inc
      return await currentMiddleware(request, runNext)
    else:
      return await handler(request)

  return await runNext()

proc requestProcessor(framework: WebFramework): Future[void] {.async.} =
  ## Process incoming requests
  while not framework.shutdown.cancelled:
    try:
      let (socket, data) = await framework.requestChannel.recv()

      # Parse request
      let request = parseRequest(data)
      echo fmt"📥 {request.httpMethod} {request.path}"

      # Find matching route
      let route = framework.matchRoute(request)

      # Apply middleware and execute handler
      let response = await framework.applyMiddleware(request, route.handler)

      # Send response
      let responseData = formatResponse(response)
      await framework.responseChannel.send((socket, responseData))

    except ChannelClosedError:
      break
    except CatchableError as e:
      echo fmt"❌ Request processing error: {e.msg}"

proc responseHandler(framework: WebFramework): Future[void] {.async.} =
  ## Handle outgoing responses
  while not framework.shutdown.cancelled:
    try:
      let (socket, responseData) = await framework.responseChannel.recv()

      await socket.send(responseData)
      socket.close()

    except ChannelClosedError:
      break
    except CatchableError as e:
      echo fmt"❌ Response handling error: {e.msg}"

proc connectionHandler(framework: WebFramework): Future[void] {.async.} =
  ## Accept and handle connections
  while not framework.shutdown.cancelled:
    try:
      let (clientSocket, address) = await framework.serverSocket.acceptAddr()

      # Read request data
      let data = await clientSocket.recv(4096)
      if data.len > 0:
        await framework.requestChannel.send((clientSocket, data))
      else:
        clientSocket.close()

    except CancelledError:
      break
    except CatchableError as e:
      echo fmt"❌ Connection error: {e.msg}"

proc run*(framework: WebFramework, port: int = 8080): Future[void] {.async.} =
  ## Start the web framework
  echo fmt"🌐 Starting web server on port {port}..."

  try:
    framework.serverSocket.setSockOpt(OptReuseAddr, true)
    framework.serverSocket.bindAddr(Port(port))
    framework.serverSocket.listen()

    echo fmt"✅ Server listening on http://localhost:{port}"

    # Start all components with TaskGroup
    await taskGroup:
      # Request processor
      discard g.spawn(proc(): Future[void] {.async.} =
        await framework.requestProcessor()
      )

      # Response handler
      discard g.spawn(proc(): Future[void] {.async.} =
        await framework.responseHandler()
      )

      # Connection handler
      discard g.spawn(proc(): Future[void] {.async.} =
        await framework.connectionHandler()
      )

      # Shutdown monitor
      discard g.spawn(proc(): Future[void] {.async.} =
        while not framework.shutdown.cancelled:
          await chronos.sleepAsync(100.milliseconds)
      )

  except CatchableError as e:
    echo fmt"❌ Server error: {e.msg}"
  finally:
    framework.serverSocket.close()
    framework.requestChannel.close()
    framework.responseChannel.close()
    echo "🛑 Web server stopped"

proc shutdown*(framework: WebFramework): Future[void] {.async.} =
  ## Gracefully shutdown the framework
  echo "🛑 Shutting down web server..."
  framework.shutdown.cancel()

# Middleware examples
proc loggingMiddleware*(req: HttpRequest, next: proc(): Future[HttpResponse] {.async.}): Future[HttpResponse] {.async.} =
  let startTime = getMonoTime()
  let response = await next()
  let duration = (getMonoTime() - startTime).inMilliseconds

  echo fmt"📊 {req.httpMethod} {req.path} -> {response.status.int} ({duration}ms)"
  return response

proc corsMiddleware*(req: HttpRequest, next: proc(): Future[HttpResponse] {.async.}): Future[HttpResponse] {.async.} =
  let response = await next()
  response.headers["Access-Control-Allow-Origin"] = "*"
  response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
  return response

# Example application
proc createSampleApp*(): WebFramework =
  let app = newWebFramework()

  # Add middleware
  app.use(loggingMiddleware)
  app.use(corsMiddleware)

  # Define routes
  app.get("/", proc(req: HttpRequest): Future[HttpResponse] {.async.} =
    return newHttpResponse().html("""
      <html>
        <head><title>nimsync Web Framework</title></head>
        <body>
          <h1>🚀 Welcome to nimsync Web Framework!</h1>
          <p>A high-performance web framework built with structured concurrency.</p>
          <ul>
            <li><a href="/api/hello">Hello API</a></li>
            <li><a href="/api/time">Current Time</a></li>
            <li><a href="/api/users">Users API</a></li>
          </ul>
        </body>
      </html>
    """)
  )

  app.get("/api/hello", proc(req: HttpRequest): Future[HttpResponse] {.async.} =
    return newHttpResponse().json(%*{
      "message": "Hello from nimsync!",
      "timestamp": $now(),
      "framework": "nimsync-web"
    })
  )

  app.get("/api/time", proc(req: HttpRequest): Future[HttpResponse] {.async.} =
    return newHttpResponse().json(%*{
      "current_time": $now(),
      "unix_timestamp": now().toTime().toUnix(),
      "timezone": "UTC"
    })
  )

  app.get("/api/users", proc(req: HttpRequest): Future[HttpResponse] {.async.} =
    return newHttpResponse().json(%*{
      "users": [
        {"id": 1, "name": "Alice", "email": "alice@example.com"},
        {"id": 2, "name": "Bob", "email": "bob@example.com"},
        {"id": 3, "name": "Charlie", "email": "charlie@example.com"}
      ],
      "total": 3
    })
  )

  app.post("/api/users", proc(req: HttpRequest): Future[HttpResponse] {.async.} =
    try:
      let userData = parseJson(req.body)
      return newHttpResponse(Created).json(%*{
        "message": "User created successfully",
        "user": userData,
        "id": 4
      })
    except JsonParsingError:
      return newHttpResponse(BadRequest).json(%*{
        "error": "Invalid JSON in request body"
      })
  )

  return app

proc main() {.async.} =
  echo "🌐 nimsync Web Framework Example"
  echo "================================="

  let app = createSampleApp()

  # Start server in background and run some test requests
  await taskGroup:
    discard g.spawn(proc(): Future[void] {.async.} =
      await app.run(8080)
    )

    discard g.spawn(proc(): Future[void] {.async.} =
      # Give server time to start
      await chronos.sleepAsync(1.seconds)

      echo "\n🧪 Testing API endpoints..."

      # Simulate some requests (in a real scenario, you'd use an HTTP client)
      echo "📍 GET / - Homepage"
      echo "📍 GET /api/hello - Hello endpoint"
      echo "📍 GET /api/time - Time endpoint"
      echo "📍 GET /api/users - Users endpoint"
      echo "📍 POST /api/users - Create user endpoint"

      echo "\n🌐 Server is running at http://localhost:8080"
      echo "Visit the URLs above to test the framework!"

      # Run for a few seconds then shutdown
      await chronos.sleepAsync(5.seconds)
      await app.shutdown()
    )

  echo "\n✅ Web framework example completed!"

when isMainModule:
  waitFor main()