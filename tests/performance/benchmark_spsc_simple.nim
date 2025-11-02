## SPSC Channel Benchmark (Simple Version)
##
## Single-threaded benchmark for SPSC channels
## Shows raw channel throughput without threading overhead

import std/[times, strformat, monotimes, math, strutils]
import ../../src/nimsync

proc formatNumber(n: int64): string =
  ## Format number with thousand separators
  let s = $n
  var res = ""
  var count = 0
  for i in countdown(s.len - 1, 0):
    if count > 0 and count mod 3 == 0:
      res = "," & res
    res = s[i] & res
    inc count
  res

proc benchmarkSPSC(operations: int64, channelSize: int): float64 =
  ## Benchmark SPSC channel (single-threaded)
  ## Returns operations per second

  let ch = newChannel[int](channelSize, ChannelMode.SPSC)

  let startTime = getMonoTime()

  # Interleaved send/receive
  var sent = 0'i64
  var received = 0'i64
  var value: int

  while received < operations:
    # Send if we can
    if sent < operations:
      if ch.trySend(sent.int):
        inc sent

    # Receive if we can
    if ch.tryReceive(value):
      inc received

  let endTime = getMonoTime()
  let duration = (endTime - startTime).inNanoseconds.float64

  # Calculate ops/sec (count both send and receive as operations)
  let totalOps = sent + received
  let throughput = (totalOps.float64 / duration) * 1_000_000_000.0

  throughput

proc main() =
  echo repeat("=", 60)
  echo "nimsync SPSC Channel Benchmark"
  echo repeat("=", 60)
  echo ""

  # System info
  echo "System Information:"
  when defined(linux):
    echo "  OS: Linux"
  when defined(macosx):
    echo "  OS: macOS"
  when defined(windows):
    echo "  OS: Windows"
  echo fmt"  Nim Version: {NimVersion}"
  echo ""

  # Warm-up
  echo "Warming up..."
  discard benchmarkSPSC(1_000_000, 1024)
  echo ""

  # Run benchmarks with different parameters
  echo "Running benchmarks..."
  echo ""

  type BenchConfig = tuple[ops: int64, size: int, name: string]
  let configs: seq[BenchConfig] = @[
    (10_000_000'i64, 16, "10M ops, 16-slot channel"),
    (10_000_000'i64, 1024, "10M ops, 1K-slot channel"),
    (100_000_000'i64, 1024, "100M ops, 1K-slot channel"),
  ]

  var results: seq[float64] = @[]

  for config in configs:
    echo fmt"Test: {config.name}"
    let throughput = benchmarkSPSC(config.ops, config.size)
    results.add(throughput)

    let opsFormatted = formatNumber(config.ops * 2)  # *2 for send+receive
    let throughputFormatted = formatNumber(throughput.int64)
    let latencyNs = 1_000_000_000.0 / throughput

    echo fmt"  Operations: {opsFormatted}"
    echo fmt"  Throughput: {throughputFormatted} ops/sec"
    echo fmt"  Latency: {latencyNs:.2f} ns/op"
    echo ""

  # Summary
  echo repeat("=", 60)
  echo "Summary"
  echo repeat("=", 60)

  # Peak throughput
  let maxThroughput = results.max()
  let maxFormatted = formatNumber(maxThroughput.int64)
  echo fmt"Peak Throughput: {maxFormatted} ops/sec"

  # Average throughput
  var sum = 0.0
  for r in results:
    sum += r
  let avgThroughput = sum / results.len.float64
  let avgFormatted = formatNumber(avgThroughput.int64)
  echo fmt"Average Throughput: {avgFormatted} ops/sec"

  echo ""
  echo "Benchmark completed successfully!"
  echo ""
  echo "To reproduce:"
  echo "  nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_spsc_simple.nim"
  echo "  ./tests/performance/benchmark_spsc_simple"

when isMainModule:
  main()
