# real_world_scenarios.nim
import nimsync, std/[random, times, strformat, asyncdispatch]

proc request_handler(request: string) {.async.} =
  # Simulate processing time
  await sleepAsync(5 + rand(20))  # 5-25ms
  if rand(100) < 5:  # 5% failure rate
    raise newException(IOError, "Request failed")

proc producer(ch: Channel[string]) {.async.} =
  for i in 0..<10000:
    let request = &"Request_{i}"
    # Add backpressure
    while not ch.trySend(request):
      echo "Backpressure detected, waiting..."
      await sleepAsync(1)
    echo &"Sent {request}"
    await sleepAsync(rand(5))  # Variable rate

proc consumer(ch: Channel[string]) {.async.} =
  var processed = 0
  while processed < 10000:
    var request: string
    if ch.tryReceive(request):
      try:
        await request_handler(request)
        inc processed
        echo &"Processed {request}"
      except:
        echo &"Failed to process {request}"
    else:
      await sleepAsync(1)  # Wait for requests

proc real_world_scenarios_test() {.async.} =
  echo "🌐 REAL WORLD SCENARIOS: Request processing with backpressure"
  var request_channel = newChannel[string](100, ChannelMode.SPSC)  # Smaller buffer for backpressure

  await all(
    producer(request_channel),
    consumer(request_channel)
  )

  echo "✅ All requests processed with backpressure"

when isMainModule:
  waitFor real_world_scenarios_test()