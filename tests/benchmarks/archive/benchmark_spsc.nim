import nimsync, std/[times, strformat]

when isMainModule:
  const Ops = 50_000_000
  let ch = newChannel[int](1024, ChannelMode.SPSC)
  
  var sent = 0
  var received = 0
  
  let t0 = cpuTime()
  
  # Interleaved producer/consumer to avoid deadlock
  while sent < Ops or received < Ops:
    # Try to send a batch
    for _ in 0..<100:
      if sent < Ops and ch.trySend(sent + 1):
        inc sent
    
    # Try to receive a batch  
    for _ in 0..<100:
      var val: int
      if received < Ops and ch.tryReceive(val):
        inc received
  
  let elapsed = cpuTime() - t0
  let throughput = Ops.float / elapsed

  echo &"=== nimsync v0.1.0 SPSC (single-threaded) ==="
  echo &"Throughput: {throughput:.0f} ops/sec"