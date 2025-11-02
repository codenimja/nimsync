## Concurrent SPSC Benchmark
##
## Tests realistic producer-consumer scenario with separate goroutines
## This shows the true multi-threaded performance with synchronization overhead

import std/[strformat, monotimes, strutils, math, times]
import chronos
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

proc benchmarkConcurrent(operations: int64, channelSize: int): Future[float64] {.async.} =
  ## Benchmark with concurrent producer/consumer
  let ch = newChannel[int](channelSize, ChannelMode.SPSC)

  proc producer() {.async.} =
    for i in 0..<operations:
      await ch.send(i.int)

  proc consumer() {.async.} =
    for i in 0..<operations:
      discard await ch.recv()

  let startTime = getMonoTime()
  await allFutures([producer(), consumer()])
  let endTime = getMonoTime()

  let duration = (endTime - startTime).inNanoseconds.float64
  let throughput = (operations.float64 / duration) * 1_000_000_000.0

  return throughput

proc main() {.async.} =
  echo repeat("=", 60)
  echo "nimsync Concurrent SPSC Benchmark"
  echo repeat("=", 60)
  echo ""

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
  discard await benchmarkConcurrent(100_000, 1024)
  echo ""

  echo "Running concurrent benchmarks..."
  echo "(Uses async send/recv with exponential backoff)"
  echo ""

  type BenchConfig = tuple[ops: int64, size: int, name: string]
  let configs: seq[BenchConfig] = @[
    (1_000_000'i64, 16, "1M ops, 16-slot channel"),
    (1_000_000'i64, 1024, "1M ops, 1K-slot channel"),
    (10_000_000'i64, 1024, "10M ops, 1K-slot channel"),
  ]

  var results: seq[float64] = @[]

  for config in configs:
    echo fmt"Test: {config.name}"
    let throughput = await benchmarkConcurrent(config.ops, config.size)
    results.add(throughput)

    let opsFormatted = formatNumber(config.ops)
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

  let maxThroughput = results.max()
  let maxFormatted = formatNumber(maxThroughput.int64)
  echo fmt"Peak Throughput: {maxFormatted} ops/sec"

  var sum = 0.0
  for r in results:
    sum += r
  let avgThroughput = sum / results.len.float64
  let avgFormatted = formatNumber(avgThroughput.int64)
  echo fmt"Average Throughput: {avgFormatted} ops/sec"

  echo ""
  echo "Note: This benchmark uses async send/recv (with 1ms polling)"
  echo "For zero-latency, use trySend/tryReceive in tight loops"
  echo ""
  echo "To reproduce:"
  echo "  nim c -r tests/performance/benchmark_concurrent.nim"

waitFor main()
