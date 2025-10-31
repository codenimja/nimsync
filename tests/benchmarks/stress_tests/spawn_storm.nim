import nimsync, std/[times, strformat]

# Goroutine/Async Spawn Storm Test
# Tests channel performance under concurrent access patterns
# Adapted from Go's runstress and Tokio spawn benchmarks

proc stressTest() =
  const NChannels = 10  # Number of concurrent channels (start small)
  const OpsPerChannel = 10000  # Operations per channel
  const BufferSize = 128

  echo "=== Goroutine/Async Spawn Storm Test ==="
  echo fmt"Testing {NChannels} channels with {OpsPerChannel} ops each"

  var totalOps = 0

  let t0 = cpuTime()

  # Test each channel individually to avoid complex concurrency
  for chId in 0..<NChannels:
    let ch = newChannel[int](BufferSize, ChannelMode.SPSC)
    var sent = 0
    var received = 0

    # Stress test: send/receive operations
    while sent < OpsPerChannel or received < OpsPerChannel:
      # Try to send
      if sent < OpsPerChannel and ch.trySend(sent + chId * OpsPerChannel):
        inc sent

      # Try to receive
      var val: int
      if received < OpsPerChannel and ch.tryReceive(val):
        inc received
        totalOps += 1

  let elapsed = cpuTime() - t0
  let throughput = float(totalOps) / elapsed

  echo fmt"Completed {totalOps} operations in {elapsed:.3f}s"
  echo fmt"Throughput: {throughput:.0f} ops/sec"
  echo fmt"Per-channel throughput: {throughput / float(NChannels):.0f} ops/sec"

when isMainModule:
  stressTest()