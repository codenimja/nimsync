# streaming_pipeline.nim
import nimsync, std/[times, random, strformat, asyncdispatch]

proc cpu_intensive_task(iterations: int): int =
  var sum = 0
  for i in 0..<iterations:
    sum += i mod 1000
  return sum

proc producer(ch: Channel[string]) {.async.} =
  for i in 0..<100_000:
    while not ch.trySend(&"event_{i}"):
      await sleepAsync(1)
    if i mod 1000 == 0:
      await sleepAsync(1)

proc transformer(input, output: Channel[string]) {.async.} =
  var processed = 0
  while processed < 100_000:
    var data: string
    if input.tryReceive(data):
      # Heavy transform
      discard cpu_intensive_task(100)
      while not output.trySend(data & "_transformed"):
        await sleepAsync(1)
      inc processed
      await sleepAsync(0)
    else:
      await sleepAsync(1)

proc consumer(ch: Channel[string]) {.async.} =
  var count = 0
  while count < 100_000:
    var data: string
    if ch.tryReceive(data):
      inc count
      if count mod 10_000 == 0:
        echo &"Consumed {count}"
    else:
      await sleepAsync(1)

proc streaming_stress_test() {.async.} =
  echo "⛓️ STREAMING PIPELINE UNDER FIRE"
  var ch1 = newChannel[string](100, ChannelMode.SPSC)
  var ch2 = newChannel[string](50, ChannelMode.SPSC)  # Backpressure!

  await all(
    producer(ch1),
    transformer(ch1, ch2),
    transformer(ch1, ch2),  # Two transformers
    consumer(ch2)
  )
  echo "Pipeline held under 100k events"

when isMainModule:
  waitFor streaming_stress_test()