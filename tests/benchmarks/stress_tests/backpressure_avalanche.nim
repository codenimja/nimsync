import nimsync, std/[times, strformat, random]

# Backpressure Avalanche Test
# Tests channel behavior under overflow conditions
# Adapted from Haskell Streamly and Python Semaphore stress tests

proc stressTest() =
  const TotalOps = 10000  # Total operations to attempt
  const BufferSize = 16   # Very small buffer to create backpressure
  const BurstSize = 100   # Operations per burst

  echo "=== Backpressure Avalanche Test ==="
  echo fmt"Testing {TotalOps} ops with buffer size {BufferSize}"

  let ch = newChannel[int](BufferSize, ChannelMode.SPSC)
  var sent = 0
  var received = 0
  var failedSends = 0

  let t0 = cpuTime()

  # Avalanche test: flood the channel
  for burst in 0..<(TotalOps div BurstSize):
    # Send burst
    for i in 0..<BurstSize:
      if sent < TotalOps:
        if ch.trySend(burst * BurstSize + i):
          inc sent
        else:
          inc failedSends

    # Try to drain some
    var val: int
    for _ in 0..<BurstSize:
      if ch.tryReceive(val):
        inc received

  let elapsed = cpuTime() - t0
  let successRate = float(received) / float(sent) * 100.0

  echo fmt"Sent: {sent}, Failed: {failedSends}, Received: {received}"
  echo fmt"Success rate: {successRate:.1f}% in {elapsed:.3f}s"
  echo fmt"Throughput: {float(received) / elapsed:.0f} ops/sec"
  echo fmt"Buffer overflow stress: {failedSends} failed sends"

when isMainModule:
  randomize()
  stressTest()