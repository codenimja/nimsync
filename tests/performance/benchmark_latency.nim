## Latency Benchmark - Measures per-operation latency distribution
##
## Industry standard: Measure p50, p95, p99, p99.9 latencies
## Reference: HdrHistogram approach used by Tokio, Netty, etc.

import std/[times, monotimes, strformat, algorithm, math]
import ../../src/nimsync

proc formatNs(ns: float64): string =
  if ns < 1000:
    return fmt"{ns:.1f} ns"
  elif ns < 1_000_000:
    return fmt"{ns/1000:.1f} µs"
  else:
    return fmt"{ns/1_000_000:.1f} ms"

proc percentile(values: seq[float64], p: float): float64 =
  let idx = int(float(values.len - 1) * p)
  values[idx]

proc benchmarkLatency(operations: int, channelSize: int): tuple[p50, p95, p99, p999, max: float64] =
  ## Measure latency distribution for send/receive operations
  let ch = newChannel[int](channelSize, ChannelMode.SPSC)
  var latencies: seq[float64] = @[]
  
  for i in 0..<operations:
    let start = getMonoTime()
    
    # Send operation
    while not ch.trySend(i):
      discard
    
    # Receive operation
    var value: int
    while not ch.tryReceive(value):
      discard
    
    let duration = (getMonoTime() - start).inNanoseconds.float64
    latencies.add(duration)
  
  # Sort for percentile calculation
  latencies.sort()
  
  result.p50 = percentile(latencies, 0.50)
  result.p95 = percentile(latencies, 0.95)
  result.p99 = percentile(latencies, 0.99)
  result.p999 = percentile(latencies, 0.999)
  result.max = latencies[^1]

proc main() =
  echo "============================================================"
  echo "nimsync Latency Distribution Benchmark"
  echo "============================================================"
  echo ""
  echo "Measuring per-operation latency percentiles"
  echo "Industry standard: p50, p95, p99, p99.9"
  echo ""
  
  # Warm-up
  echo "Warming up..."
  discard benchmarkLatency(1_000, 1024)
  echo ""
  
  # Run benchmark
  echo "Running 10K operations..."
  let result = benchmarkLatency(10_000, 1024)
  
  echo ""
  echo "Latency Distribution:"
  echo fmt"  p50  (median):  {formatNs(result.p50)}"
  echo fmt"  p95:            {formatNs(result.p95)}"
  echo fmt"  p99:            {formatNs(result.p99)}"
  echo fmt"  p99.9:          {formatNs(result.p999)}"
  echo fmt"  max:            {formatNs(result.max)}"
  echo ""
  
  # Quality assessment
  if result.p99 < 1000:  # < 1µs
    echo "✅ Excellent: p99 latency < 1µs"
  elif result.p99 < 10_000:  # < 10µs
    echo "✅ Good: p99 latency < 10µs"
  else:
    echo "⚠️  High tail latency detected"
  
  echo ""
  echo "To reproduce:"
  echo "  nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_latency.nim"
  echo "  ./tests/performance/benchmark_latency"

when isMainModule:
  main()
