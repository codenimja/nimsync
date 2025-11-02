## Stress Benchmark - Maximum sustainable throughput under extreme load
##
## Industry standard: Push system to limits, measure breaking point
## Reference: Similar to Apache JMeter/Gatling stress testing

import std/[times, monotimes, strformat, strutils]
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

proc stressTest(operations: int, channelSize: int): tuple[
    throughput: float64,
    failedSends: int,
    failedRecvs: int
  ] =
  ## Stress test with maximum operations
  let ch = newChannel[int](channelSize, ChannelMode.SPSC)
  
  var sent = 0
  var received = 0
  var failedSends = 0
  var failedRecvs = 0
  var value: int
  
  let startTime = getMonoTime()
  
  # Maximum pressure - no backoff
  while received < operations:
    if sent < operations:
      if ch.trySend(sent):
        inc sent
      else:
        inc failedSends
    
    if ch.tryReceive(value):
      inc received
    else:
      inc failedRecvs
  
  let duration = inNanoseconds(getMonoTime() - startTime).float64
  let totalOps = operations * 2
  let throughput = (totalOps.float64 / duration) * 1_000_000_000.0
  
  result.throughput = throughput
  result.failedSends = failedSends
  result.failedRecvs = failedRecvs

proc main() =
  echo repeat("=", 60)
  echo "nimsync Stress Benchmark"
  echo repeat("=", 60)
  echo ""
  echo "Maximum sustainable throughput test"
  echo "(Push system to limits)"
  echo ""
  
  # Warm-up
  echo "Warming up..."
  discard stressTest(10_000, 1024)
  echo ""
  
  echo "Running stress tests..."
  echo ""
  
  type StressLevel = tuple[ops: int, name: string]
  let levels: seq[StressLevel] = @[
    (100_000, "Light: 100K operations"),
    (250_000, "Medium: 250K operations"),
    (500_000, "Heavy: 500K operations"),
  ]
  
  for level in levels:
    echo fmt"Test: {level.name}"
    echo "  Running..."
    
    let result = stressTest(level.ops, 1024)
    
    let opsFormatted = formatNumber((level.ops * 2).int64)
    let throughputFormatted = formatNumber(result.throughput.int64)
    
    echo fmt"  Total Operations: {opsFormatted}"
    echo fmt"  Throughput: {throughputFormatted} ops/sec"
    echo fmt"  Failed Sends: {formatNumber(result.failedSends.int64)}"
    echo fmt"  Failed Receives: {formatNumber(result.failedRecvs.int64)}"
    
    # Contention metric
    let contentionRate = ((result.failedSends + result.failedRecvs).float64 / 
                          (level.ops * 2).float64) * 100.0
    echo fmt"  Contention Rate: {contentionRate:.2f}%"
    
    if contentionRate < 10.0:
      echo "  ✅ Low contention - efficient utilization"
    elif contentionRate < 30.0:
      echo "  ⚠️  Moderate contention"
    else:
      echo "  ⚠️  High contention - consider larger buffer"
    
    echo ""
  
  echo repeat("=", 60)
  echo "Stress Test Complete"
  echo repeat("=", 60)
  echo ""
  echo "Lower contention rate indicates better channel utilization"
  echo ""
  echo "To reproduce:"
  echo "  nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_stress.nim"
  echo "  ./tests/performance/benchmark_stress"

when isMainModule:
  main()
