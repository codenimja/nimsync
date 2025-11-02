## Channel Size Benchmark - Tests performance across different buffer sizes
##
## Industry standard: Measure impact of buffer size on throughput
## Reference: Similar to Ring Buffer sizing tests (Disruptor, LMAX)

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

proc benchmarkChannelSize(channelSize: int, operations: int): float64 =
  ## Measure throughput for given channel size
  let ch = newChannel[int](channelSize, ChannelMode.SPSC)
  
  let startTime = getMonoTime()
  
  var sent = 0
  var received = 0
  var value: int
  
  while received < operations:
    if sent < operations and ch.trySend(sent):
      inc sent
    if ch.tryReceive(value):
      inc received
  
  let duration = inNanoseconds(getMonoTime() - startTime).float64
  let totalOps = operations * 2  # send + recv
  let throughput = (totalOps.float64 / duration) * 1_000_000_000.0
  
  return throughput

proc main() =
  echo repeat("=", 60)
  echo "nimsync Channel Size Benchmark"
  echo repeat("=", 60)
  echo ""
  echo "Tests impact of buffer size on throughput"
  echo "(Helps optimize channel sizing for your workload)"
  echo ""
  
  # Warm-up
  echo "Warming up..."
  discard benchmarkChannelSize(64, 10_000)
  echo ""
  
  echo "Running benchmarks..."
  echo ""
  
  # Test power-of-2 sizes (common practice)
  let sizes = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
  let operations = 100_000
  
  var results: seq[tuple[size: int, throughput: float64]] = @[]
  
  for size in sizes:
    let throughput = benchmarkChannelSize(size, operations)
    results.add((size, throughput))
    
    echo fmt"Channel Size: {size:>6} slots -> {formatNumber(throughput.int64)} ops/sec"
  
  # Find optimal size
  echo ""
  echo repeat("=", 60)
  echo "Analysis"
  echo repeat("=", 60)
  
  var maxThroughput = 0.0
  var optimalSize = 0
  
  for r in results:
    if r.throughput > maxThroughput:
      maxThroughput = r.throughput
      optimalSize = r.size
  
  echo fmt"Optimal Size: {optimalSize} slots"
  echo fmt"Peak Throughput: {formatNumber(maxThroughput.int64)} ops/sec"
  echo ""
  
  # Show efficiency relative to optimal
  echo "Efficiency relative to optimal:"
  for r in results:
    let efficiency = (r.throughput / maxThroughput) * 100.0
    let bar = repeat("█", int(efficiency / 2))
    echo fmt"  {r.size:>6} slots: {bar} {efficiency:.1f}%"
  
  echo ""
  echo "Recommendations:"
  echo "  • Small buffers (8-32): Lower memory, higher contention"
  echo "  • Medium buffers (64-256): Balanced performance"
  echo "  • Large buffers (512+): Best throughput, more memory"
  echo ""
  echo "To reproduce:"
  echo "  nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_sizes.nim"
  echo "  ./tests/performance/benchmark_sizes"

when isMainModule:
  main()
