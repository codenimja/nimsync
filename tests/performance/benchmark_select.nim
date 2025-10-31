## Channel Operations Performance Benchmark
##
## Measures basic channel send/recv performance without select.
## Target: 34M ops/sec

import std/[times, strformat, atomics]
import nimsync

when isMainModule:
  const OPERATIONS = 10_000_000
  var ch = newChannel[int](1024, ChannelMode.SPSC)

  # Pre-fill channel for recv operations
  for i in 0 ..< 512:
    discard ch.trySend(i)

  var operations = Atomic[int]()
  operations.store(0, moRelaxed)

  proc channelOps() =
    for i in 0 ..< OPERATIONS:
      # Alternate between send and recv to test both operations
      if (i mod 2) == 0:
        if ch.trySend(i):
          discard operations.fetchAdd(1, moRelaxed)
      else:
        var msg: int
        if ch.tryReceive(msg):
          discard operations.fetchAdd(1, moRelaxed)

  echo fmt"🏃 Running Channel Operations benchmark ({OPERATIONS} operations)..."

  let startTime = cpuTime()
  channelOps()
  let endTime = cpuTime()

  let durationSec = endTime - startTime
  let throughput = operations.load(moRelaxed).float64 / durationSec

  echo fmt"✅ Completed in {durationSec:.3f}s"
  echo fmt"📊 Throughput: {throughput / 1_000_000:.2f}M ops/sec"
  echo fmt"🎯 Target: 34M ops/sec"

  if operations.load(moRelaxed) < OPERATIONS div 4:
    echo fmt"❌ Error: Too few operations completed: {operations.load(moRelaxed)}"
    quit(1)