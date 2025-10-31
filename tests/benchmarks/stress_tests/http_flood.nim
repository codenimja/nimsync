import nimsync, std/[times, strformat, random]

# IO-Bound HTTP Flood Test (Simplified)
# Tests channel performance under simulated IO load
# Adapted from TechEmpower benchmarks

proc simulateHttpRequest(ch: Channel[string], id: int) =
  # Simulate HTTP request processing through channel
  let requestData = fmt"Request {id}: {rand(1000)}"
  while not ch.trySend(requestData): discard

  # Simulate response processing
  var response: string
  if ch.tryReceive(response):
    # Simulate processing time
    for i in 0..<100: discard

proc stressTest() =
  const NRequests = 1000  # Number of simulated requests
  const BufferSize = 64   # Small buffer to create backpressure

  echo "=== IO-Bound HTTP Flood Test ==="
  echo fmt"Simulating {NRequests} concurrent requests"

  var channels: seq[Channel[string]] = @[]
  var totalProcessed = 0

  # Create channels for request processing
  for i in 0..<NRequests:
    channels.add(newChannel[string](BufferSize, ChannelMode.SPSC))

  let t0 = cpuTime()

  # Process requests through channels
  for i in 0..<NRequests:
    simulateHttpRequest(channels[i], i)

    # Try to drain responses
    var response: string
    if channels[i].tryReceive(response):
      totalProcessed += 1

  let elapsed = cpuTime() - t0
  let throughput = float(totalProcessed) / elapsed

  echo fmt"Processed {totalProcessed}/{NRequests} requests in {elapsed:.3f}s"
  echo fmt"Throughput: {throughput:.0f} req/sec"
  echo fmt"Simulated load: {float(NRequests) / elapsed:.0f} req/sec"

when isMainModule:
  randomize()
  stressTest()