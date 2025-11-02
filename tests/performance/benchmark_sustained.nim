## Sustained Load Benchmark - Long-duration performance stability test
##
## Industry standard: Verify no degradation over extended operation
## Reference: Similar to Cassandra/ScyllaDB sustained load testing

import std/[times, monotimes, strformat, strutils, os]
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

proc formatDuration(seconds: float64): string =
  if seconds < 60:
    return fmt"{seconds:.1f}s"
  else:
    let mins = int(seconds / 60)
    let secs = seconds - (mins.float64 * 60)
    return fmt"{mins}m {secs:.0f}s"

proc benchmarkSustained(durationSeconds: int, channelSize: int): tuple[
    avgThroughput: float64,
    minThroughput: float64,
    maxThroughput: float64,
    samples: int,
    sampleData: seq[tuple[time: float64, throughput: float64]]
  ] =
  ## Run sustained load for specified duration, measure stability
  let ch = newChannel[int](channelSize, ChannelMode.SPSC)
  let endTime = getMonoTime() + initDuration(seconds = durationSeconds)
  let benchStart = getMonoTime()
  
  var throughputs: seq[float64] = @[]
  var timeStamps: seq[float64] = @[]
  var sampleNumber = 0
  
  while getMonoTime() < endTime:
    let sampleStart = getMonoTime()
    let sampleOps = 50_000  # 50K ops per sample
    
    var sent = 0
    var received = 0
    var value: int
    
    while received < sampleOps:
      if sent < sampleOps and ch.trySend(sent):
        inc sent
      if ch.tryReceive(value):
        inc received
    
    let sampleDuration = inNanoseconds(getMonoTime() - sampleStart).float64
    let sampleThroughput = (sampleOps.float64 * 2 / sampleDuration) * 1_000_000_000.0
    let elapsedTime = inNanoseconds(getMonoTime() - benchStart).float64 / 1_000_000_000.0
    
    throughputs.add(sampleThroughput)
    timeStamps.add(elapsedTime)
    
    inc sampleNumber
  
  # Calculate statistics
  var sum = 0.0
  var minVal = throughputs[0]
  var maxVal = throughputs[0]
  
  for t in throughputs:
    sum += t
    if t < minVal: minVal = t
    if t > maxVal: maxVal = t
  
  # Prepare sample data
  var samples: seq[tuple[time: float64, throughput: float64]] = @[]
  for i in 0..<throughputs.len:
    samples.add((timeStamps[i], throughputs[i]))
  
  result.avgThroughput = sum / throughputs.len.float64
  result.minThroughput = minVal
  result.maxThroughput = maxVal
  result.samples = throughputs.len
  result.sampleData = samples

proc main() =
  echo repeat("=", 60)
  echo "nimsync Sustained Load Benchmark"
  echo repeat("=", 60)
  echo ""
  echo "Measures performance stability over extended duration"
  echo ""
  
  # Create timestamped results directory
  let timestamp = now().format("yyyyMMddHHmmss")
  let resultsDir = "benchmark_results_" & timestamp
  createDir(resultsDir)
  
  let csvFile = resultsDir / "sustained_timeseries.csv"
  var csv = open(csvFile, fmWrite)
  csv.writeLine("test_name,duration_sec,elapsed_time_sec,throughput_ops_per_sec")
  
  # Short warm-up
  echo "Warming up..."
  discard benchmarkSustained(1, 1024)
  echo ""
  
  # Run sustained tests
  type BenchConfig = tuple[duration: int, name: string]
  let configs: seq[BenchConfig] = @[
    (3, "3-second sustained load"),
    (5, "5-second sustained load"),
    (10, "10-second sustained load"),
  ]
  
  for config in configs:
    echo fmt"Running: {config.name}"
    echo "Press Ctrl+C to skip if needed..."
    echo ""
    
    let result = benchmarkSustained(config.duration, 1024)
    
    # Write CSV data
    for sample in result.sampleData:
      csv.writeLine(fmt"{config.name},{config.duration},{sample.time:.6f},{sample.throughput:.0f}")
    
    echo fmt"  Duration: {formatDuration(config.duration.float64)}"
    echo fmt"  Samples: {result.samples}"
    echo fmt"  Average Throughput: {formatNumber(result.avgThroughput.int64)} ops/sec"
    echo fmt"  Min Throughput: {formatNumber(result.minThroughput.int64)} ops/sec"
    echo fmt"  Max Throughput: {formatNumber(result.maxThroughput.int64)} ops/sec"
    
    let variance = ((result.maxThroughput - result.minThroughput) / result.avgThroughput) * 100.0
    echo fmt"  Variance: {variance:.1f}%"
    
    if variance < 5.0:
      echo "  ✅ Excellent stability"
    elif variance < 15.0:
      echo "  ✅ Good stability"
    else:
      echo "  ⚠️  Performance fluctuation detected"
    
    echo ""
  
  csv.close()
  
  echo repeat("=", 60)
  echo "Sustained Load Test Complete"
  echo repeat("=", 60)
  echo ""
  echo fmt"Results saved to: {csvFile}"
  echo "Low variance indicates stable performance (no degradation)"
  echo ""
  echo "To reproduce:"
  echo "  nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_sustained.nim"
  echo "  ./tests/performance/benchmark_sustained"

when isMainModule:
  main()
