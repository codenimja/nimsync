## HTTP Client Example using nimsync
##
## Demonstrates:
## - Concurrent HTTP requests with TaskGroup
## - Error handling and timeout management
## - Channel-based result collection
## - Performance benchmarking

import std/[httpclient, json, strformat, times, strutils]
import chronos
import ../../src/nimsync

type
  HttpRequest* = object
    url*: string
    httpMethod*: string
    headers*: seq[(string, string)]
    body*: string

  HttpResponse* = object
    url*: string
    statusCode*: int
    headers*: seq[(string, string)]
    body*: string
    duration*: float64
    error*: string

  HttpClient = ref object
    client: AsyncHttpClient
    timeout: chronos.Duration
    maxConcurrency: int

proc newHttpClient*(timeout: chronos.Duration = chronos.seconds(30),
                   maxConcurrency: int = 10): HttpClient =
  ## Create a new async HTTP client with nimsync integration
  HttpClient(
    client: newAsyncHttpClient(),
    timeout: timeout,
    maxConcurrency: maxConcurrency
  )

proc makeRequest(client: HttpClient, request: HttpRequest): Future[HttpResponse] {.async.} =
  ## Make a single HTTP request with timeout and error handling
  let startTime = getMonoTime()

  try:
    await withTimeout(client.timeout):
      let response = await client.client.request(
        request.url,
        request.method,
        request.body
      )

      let endTime = getMonoTime()
      let duration = (endTime - startTime).inMilliseconds.float64 / 1000.0

      return HttpResponse(
        url: request.url,
        statusCode: response.code.int,
        headers: @[],  # Simplified for example
        body: await response.body,
        duration: duration,
        error: ""
      )

  except AsyncTimeoutError:
    return HttpResponse(
      url: request.url,
      statusCode: 0,
      error: "Request timeout"
    )
  except CatchableError as e:
    return HttpResponse(
      url: request.url,
      statusCode: 0,
      error: e.msg
    )

proc fetchConcurrently*(client: HttpClient,
                       requests: seq[HttpRequest]): Future[seq[HttpResponse]] {.async.} =
  ## Fetch multiple URLs concurrently using TaskGroup
  var responses: seq[HttpResponse] = @[]
  let resultChannel = newChannel[HttpResponse](requests.len, ChannelMode.MPSC)

  await taskGroup:
    # Spawn concurrent requests with concurrency limit
    var activeRequests = 0

    for i, request in requests:
      if activeRequests >= client.maxConcurrency:
        # Wait for a result before spawning more
        let response = await resultChannel.recv()
        responses.add(response)
        activeRequests.dec

      # Spawn request task
      discard g.spawn(proc(): Future[void] {.async.} =
        let response = await client.makeRequest(request)
        await resultChannel.send(response)
      )
      activeRequests.inc

    # Collect remaining responses
    while responses.len < requests.len:
      let response = await resultChannel.recv()
      responses.add(response)

  resultChannel.close()
  return responses

proc benchmark*(urls: seq[string], concurrency: int = 5): Future[void] {.async.} =
  ## Benchmark HTTP client performance
  echo fmt"🚀 Benchmarking {urls.len} URLs with concurrency {concurrency}"

  let client = newHttpClient(chronos.seconds(10), concurrency)
  let requests = urls.mapIt(HttpRequest(url: it, method: "GET"))

  let startTime = getMonoTime()
  let responses = await client.fetchConcurrently(requests)
  let endTime = getMonoTime()

  let totalTime = (endTime - startTime).inMilliseconds.float64 / 1000.0

  # Analyze results
  var successful = 0
  var errors = 0
  var totalResponseTime = 0.0

  for response in responses:
    if response.error.len == 0 and response.statusCode >= 200 and response.statusCode < 300:
      successful.inc
      totalResponseTime += response.duration
    else:
      errors.inc
      echo fmt"❌ {response.url}: {response.error}"

  # Print benchmark results
  echo "\n📊 Benchmark Results:"
  echo fmt"  Total time: {totalTime:.2f}s"
  echo fmt"  Successful: {successful}/{responses.len}"
  echo fmt"  Errors: {errors}"
  echo fmt"  Requests/sec: {responses.len.float64 / totalTime:.2f}"

  if successful > 0:
    echo fmt"  Avg response time: {totalResponseTime / successful.float64:.2f}s"
    echo fmt"  Throughput: {successful.float64 / totalTime:.2f} successful req/sec"

proc downloadAndProcess*(urls: seq[string]): Future[void] {.async.} =
  ## Download URLs and process responses with structured concurrency
  echo fmt"📥 Downloading and processing {urls.len} URLs..."

  let client = newHttpClient()
  let requests = urls.mapIt(HttpRequest(url: it, method: "GET"))
  let processingChannel = newChannel[HttpResponse](10, ChannelMode.SPSC)

  # Use TaskGroup for structured concurrency
  await taskGroup:
    # Downloader task
    discard g.spawn(proc(): Future[void] {.async.} =
      let responses = await client.fetchConcurrently(requests)
      for response in responses:
        await processingChannel.send(response)
      processingChannel.close()
    )

    # Processor task
    discard g.spawn(proc(): Future[void] {.async.} =
      while not processingChannel.closed:
        try:
          let response = await processingChannel.recv()

          if response.error.len == 0:
            echo fmt"✅ {response.url} ({response.statusCode}) - {response.body.len} bytes in {response.duration:.2f}s"

            # Simulate processing
            if response.body.contains("json"):
              echo "  📄 Detected JSON content"
            elif response.body.contains("html"):
              echo "  🌐 Detected HTML content"

          else:
            echo fmt"❌ {response.url}: {response.error}"

        except ChannelClosedError:
          break

proc main() {.async.} =
  echo "🌐 HTTP Client Example with nimsync"
  echo "===================================="

  # Example URLs for testing
  let testUrls = @[
    "https://httpbin.org/json",
    "https://httpbin.org/html",
    "https://httpbin.org/xml",
    "https://httpbin.org/delay/1",
    "https://httpbin.org/status/200",
    "https://httpbin.org/status/404",
    "https://jsonplaceholder.typicode.com/posts/1",
    "https://jsonplaceholder.typicode.com/users/1"
  ]

  try:
    # Demonstrate concurrent fetching with error handling
    echo "\n1️⃣ Basic concurrent fetching:"
    await downloadAndProcess(testUrls[0..3])

    echo "\n2️⃣ Performance benchmark:"
    await benchmark(testUrls, concurrency = 3)

    # Demonstrate timeout and cancellation
    echo "\n3️⃣ Timeout handling:"
    await withTimeout(chronos.seconds(5)):
      await benchmark(@["https://httpbin.org/delay/10"], concurrency = 1)

  except AsyncTimeoutError:
    echo "⏰ Operation timed out as expected"
  except CatchableError as e:
    echo fmt"❌ Error: {e.msg}"

  echo "\n✅ HTTP Client example completed!"

when isMainModule:
  waitFor main()