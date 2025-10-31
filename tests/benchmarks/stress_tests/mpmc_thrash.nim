import nimsync, std/[times, strformat, random]

# Multi-Producer Channel Thrash Test
# Tests channel performance under high load
# Adapted from Rust Crossbeam and Go channel benchmarks

proc stressTest() =
  const NProducers = 5
  const NConsumers = 3
  const MsgsPerProducer = 1000
  const BufferSize = 256

  echo "=== Multi-Producer Channel Thrash Test ==="
  echo fmt"{NProducers} producers, {NConsumers} consumers, {MsgsPerProducer} msgs each"

  let ch = newChannel[int](BufferSize, ChannelMode.SPSC)
  var totalSent = 0
  var totalReceived = 0

  let t0 = cpuTime()

  # Simulate producers - send all messages
  for p in 0..<NProducers:
    for i in 0..<MsgsPerProducer:
      let val = p * 10000 + i
      if ch.trySend(val):
        inc totalSent

  # Simulate consumers - receive all messages
  for c in 0..<NConsumers:
    var val: int
    while totalReceived < totalSent and ch.tryReceive(val):
      inc totalReceived

  let elapsed = cpuTime() - t0
  let throughput = float(totalReceived) / elapsed

  echo fmt"Sent {totalSent} messages, received {totalReceived} in {elapsed:.3f}s"
  echo fmt"Throughput: {throughput:.0f} msgs/sec"
  echo fmt"Note: Using SPSC mode (MPMC not yet implemented in v0.1.0)"

when isMainModule:
  randomize()
  stressTest()