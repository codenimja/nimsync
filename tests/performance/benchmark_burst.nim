## Burst Benchmark - Measures performance under burst load patterns
##
## Industry standard: Test bursty workloads (common in real applications)
## Reference: Similar to Redis/Memcached burst testing

import std/[times, monotimes, strformat, strutils, math]
import ../../src/nimsync

proc formatNumber(n: int64): string =
  let s = $n
  var res = ""
  var count = 0
  for i in countdown(s.len - 1, 0):
    if count > 0 and count mod 3 == 0:
      res = "," & res
    res = s[i] & res
    inc count
  res

proc benchmarkBurst(burstSize: int, numBursts: int, channelSize: int): float64 =
  ## Send data in bursts, measure throughput
  let ch = newChannel[int](channelSize, ChannelMode.SPSC)
  let totalOps = burstSize * numBursts * 2  # send + recv
  
  let startTime = getMonoTime()
  
  for burst in 0..<numBursts:
    # Burst send
    for i in 0..<burstSize:
      while not ch.trySend(i):
        discard
    
    # Burst receive
    var value: int
    for i in 0..<burstSize:
      while not ch.tryReceive(value):
        discard
  
  let duration = inNanoseconds(getMonoTime() - startTime).float64
  let throughput = (totalOps.float64 / duration) * 1_000_000_000.0
  
  return throughput

proc main() =
  echo repeat("=", 60)
  echo "nimsync Burst Load Benchmark"
  echo repeat("=", 60)
  echo ""
  echo "Tests performance under bursty workload patterns"
  echo "(Common in real-world applications)"
  echo ""
  
  # Warm-up
  echo "Warming up..."
  discard benchmarkBurst(50, 100, 1024)
  echo ""
  
  echo "Running benchmarks..."
  echo ""
  
  type BenchConfig = tuple[burstSize: int, numBursts: int, name: string]
  let configs: seq[BenchConfig] = @[
    (100, 100, "Small bursts: 100 ops x 100 bursts"),
    (250, 100, "Medium bursts: 250 ops x 100 bursts"),
    (500, 100, "Large bursts: 500 ops x 100 bursts"),
  ]
  
  var results: seq[float64] = @[]
  
  for config in configs:
    echo fmt"Test: {config.name}"
    let throughput = benchmarkBurst(config.burstSize, config.numBursts, 1024)
    results.add(throughput)
    
    let totalOps = config.burstSize * config.numBursts * 2
    let opsFormatted = formatNumber(totalOps.int64)
    let throughputFormatted = formatNumber(throughput.int64)
    
    echo fmt"  Total Operations: {opsFormatted}"
    echo fmt"  Throughput: {throughputFormatted} ops/sec"
    echo ""
  
  # Analysis
  echo repeat("=", 60)
  echo "Summary"
  echo repeat("=", 60)
  
  let avgThroughput = results.sum() / results.len.float64
  let minThroughput = results.min()
  let maxThroughput = results.max()
  let variance = ((maxThroughput - minThroughput) / avgThroughput) * 100.0
  
  echo fmt"Average Throughput: {formatNumber(avgThroughput.int64)} ops/sec"
  echo fmt"Variance: {variance:.1f}% (lower is better)"
  
  if variance < 10.0:
    echo "✅ Excellent: Consistent performance across burst sizes"
  elif variance < 25.0:
    echo "✅ Good: Stable under varying burst patterns"
  else:
    echo "⚠️  Performance varies significantly with burst size"
  
  echo ""
  echo "To reproduce:"
  echo "  nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_burst.nim"
  echo "  ./tests/performance/benchmark_burst"

when isMainModule:
  main()
