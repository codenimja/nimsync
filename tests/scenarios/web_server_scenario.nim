## Web Server Scenario Test
## Demonstrates nimsync usage in a concurrent web server handling multiple requests
## with mock data simulating real HTTP traffic patterns

import nimsync
import std/[tables, strutils, random]

type
  MockRequest = object
    id: int
    path: string
    method: string
    data: string

  MockResponse = object
    status: int
    body: string

proc mockDatabaseLookup(id: int): Future[string] {.async.} =
  # Simulate database delay
  await sleepAsync(10.milliseconds)
  return "User data for ID: " & $id

proc mockExternalApiCall(endpoint: string): Future[string] {.async.} =
  # Simulate external API delay
  await sleepAsync(20.milliseconds)
  return "External data from: " & endpoint

proc handleRequest(req: MockRequest): Future[MockResponse] {.async.} =
  case req.path
  of "/user":
    let userData = await mockDatabaseLookup(req.id)
    return MockResponse(status: 200, body: userData)
  of "/api/data":
    let apiData = await mockExternalApiCall("/api/v1/data")
    return MockResponse(status: 200, body: apiData)
  of "/slow":
    await sleepAsync(100.milliseconds)  # Simulate slow endpoint
    return MockResponse(status: 200, body: "Slow response")
  else:
    return MockResponse(status: 404, body: "Not found")

proc webServerScenario*() {.async.} =
  ## Main test scenario: Simulate a web server handling concurrent requests
  echo "Starting web server scenario with mock data..."

  # Mock request data
  let mockRequests = @[
    MockRequest(id: 1, path: "/user", method: "GET", data: ""),
    MockRequest(id: 2, path: "/api/data", method: "GET", data: ""),
    MockRequest(id: 3, path: "/slow", method: "GET", data: ""),
    MockRequest(id: 4, path: "/user", method: "GET", data: ""),
    MockRequest(id: 5, path: "/invalid", method: "GET", data: ""),
  ]

  # Use TaskGroup for structured concurrency
  await taskGroup:
    for req in mockRequests:
      proc handle(req: MockRequest) {.async.} =
        let response = await handleRequest(req)
        echo &"Request {req.id} ({req.path}): Status {response.status} - {response.body}"
      discard g.spawn handle(req)

  echo "Web server scenario completed."

when isMainModule:
  waitFor webServerScenario()