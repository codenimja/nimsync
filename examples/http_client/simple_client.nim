## Simple HTTP Client Example using nimsync
##
## Demonstrates basic concurrent HTTP requests

import std/[httpclient, strformat, times]
import chronos
import nimsync

proc fetchUrl(url: string): Future[string] {.async.} =
  ## Fetch a single URL
  let client = newAsyncHttpClient()
  try:
    let response = await client.get(url)
    let body = await response.body
    client.close()
    return fmt"✅ {url}: {response.code} ({body.len} bytes)"
  except CatchableError as e:
    if not client.isNil:
      client.close()
    return fmt"❌ {url}: {e.msg}"

proc main() {.async.} =
  echo "🌐 Simple HTTP Client Example with nimsync"
  echo "==========================================="

  let urls = @[
    "https://httpbin.org/json",
    "https://httpbin.org/html",
    "https://httpbin.org/xml",
    "https://jsonplaceholder.typicode.com/posts/1"
  ]

  let startTime = getMonoTime()

  # Use TaskGroup for concurrent fetching
  var results: seq[string] = @[]

  await taskGroup:
    for url in urls:
      discard g.spawn(proc(): Future[void] {.async.} =
        let result = await fetchUrl(url)
        results.add(result)
        echo result
      )

  let endTime = getMonoTime()
  let duration = (endTime - startTime).inMilliseconds.float64 / 1000.0

  echo fmt"\n📊 Fetched {urls.len} URLs in {duration:.2f}s"
  echo "✅ HTTP client example completed!"

when isMainModule:
  waitFor main()