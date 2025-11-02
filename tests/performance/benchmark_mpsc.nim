## Benchmarks comparing MPSC vs SPSC channel performance
##
## Tests throughput, latency, and scalability under various workloads

import std/[atomics, times, strformat, strutils]
import ../../src/private/channel_spsc as ch

# Avoid ambiguity with system.Channel
type Channel[T] = ch.Channel[T]
const SPSC = ch.SPSC
const MPSC = ch.MPSC

type
  BenchResult = object
    name: string
    items: int
    duration: float
    throughputMops: float
    avgLatencyNs: float

proc formatBenchResult(r: BenchResult): string =
  &"{r.name:<40} | {r.items:>10} items | {r.duration:>6.3f}s | {r.throughputMops:>7.2f} Mops/s | {r.avgLatencyNs:>8.1f} ns/op"

# ============================================================================
# SPSC Benchmarks
# ============================================================================

proc benchSPSCThroughput(capacity, numItems: int): BenchResult =
  let chan = ch.newChannel[int](capacity, SPSC)
  var producerThread: Thread[tuple[chan: Channel[int], n: int]]

  proc producer(args: tuple[chan: Channel[int], n: int]) {.thread.} =
    for i in 0 ..< args.n:
      while not args.chan.trySend(i):
        discard

  let t0 = cpuTime()
  createThread(producerThread, producer, (chan, numItems))

  var val: int
  for _ in 0 ..< numItems:
    while not chan.tryReceive(val):
      discard

  joinThread(producerThread)
  let elapsed = cpuTime() - t0

  BenchResult(
    name: &"SPSC throughput (cap={capacity})",
    items: numItems,
    duration: elapsed,
    throughputMops: float(numItems) / elapsed / 1_000_000.0,
    avgLatencyNs: elapsed / float(numItems) * 1_000_000_000.0
  )

proc benchSPSCLatency(capacity, numSamples: int): BenchResult =
  let chan = ch.newChannel[int](capacity, SPSC)
  var producerThread: Thread[tuple[chan: Channel[int], n: int]]

  proc producer(args: tuple[chan: Channel[int], n: int]) {.thread.} =
    for i in 0 ..< args.n:
      while not args.chan.trySend(i):
        discard

  createThread(producerThread, producer, (chan, numSamples))

  var latencies = newSeq[float](numSamples)
  var val: int

  for i in 0 ..< numSamples:
    let t0 = cpuTime()
    while not chan.tryReceive(val):
      discard
    latencies[i] = (cpuTime() - t0) * 1_000_000_000.0

  joinThread(producerThread)

  var sum = 0.0
  for lat in latencies:
    sum += lat

  BenchResult(
    name: &"SPSC latency (cap={capacity})",
    items: numSamples,
    duration: sum / 1_000_000_000.0,
    throughputMops: 0.0,
    avgLatencyNs: sum / float(numSamples)
  )

# ============================================================================
# MPSC Benchmarks
# ============================================================================

proc benchMPSCThroughput(capacity, numProducers, itemsPerProducer: int): BenchResult =
  let chan = ch.newChannel[int](capacity, MPSC)
  let totalItems = numProducers * itemsPerProducer

  var producerThreads = newSeq[Thread[tuple[chan: Channel[int], n: int]]](numProducers)

  proc producer(args: tuple[chan: Channel[int], n: int]) {.thread.} =
    for i in 0 ..< args.n:
      while not args.chan.trySend(i):
        discard

  let t0 = cpuTime()

  for i in 0 ..< numProducers:
    createThread(producerThreads[i], producer, (chan, itemsPerProducer))

  var val: int
  for _ in 0 ..< totalItems:
    while not chan.tryReceive(val):
      discard

  for i in 0 ..< numProducers:
    joinThread(producerThreads[i])

  let elapsed = cpuTime() - t0

  BenchResult(
    name: &"MPSC throughput {numProducers}P (cap={capacity})",
    items: totalItems,
    duration: elapsed,
    throughputMops: float(totalItems) / elapsed / 1_000_000.0,
    avgLatencyNs: elapsed / float(totalItems) * 1_000_000_000.0
  )

proc benchMPSCLatency(capacity, numProducers, numSamples: int): BenchResult =
  let chan = ch.newChannel[int](capacity, MPSC)
  var producerThreads = newSeq[Thread[tuple[chan: Channel[int], n: int]]](numProducers)

  proc producer(args: tuple[chan: Channel[int], n: int]) {.thread.} =
    for i in 0 ..< args.n:
      while not args.chan.trySend(i):
        discard

  for i in 0 ..< numProducers:
    createThread(producerThreads[i], producer, (chan, numSamples))

  let totalItems = numProducers * numSamples
  var latencies = newSeq[float](totalItems)
  var val: int

  for i in 0 ..< totalItems:
    let t0 = cpuTime()
    while not chan.tryReceive(val):
      discard
    latencies[i] = (cpuTime() - t0) * 1_000_000_000.0

  for i in 0 ..< numProducers:
    joinThread(producerThreads[i])

  var sum = 0.0
  for lat in latencies:
    sum += lat

  BenchResult(
    name: &"MPSC latency {numProducers}P (cap={capacity})",
    items: totalItems,
    duration: sum / 1_000_000_000.0,
    throughputMops: 0.0,
    avgLatencyNs: sum / float(totalItems)
  )

# ============================================================================
# Scalability Benchmark
# ============================================================================

proc benchMPSCScalability(): seq[BenchResult] =
  result = @[]
  const ItemsPerProducer = 100_000
  const Capacity = 1024

  echo "\n=== MPSC Scalability (fixed ", ItemsPerProducer, " items/producer) ==="
  echo &"{\"Benchmark\":<40} | {\"Items\":>10} | {\"Time\":>8} | {\"Throughput\":>14} | {\"Latency\":>12}"
  echo repeat("=", 100)

  for numProducers in [1, 2, 4, 8]:
    let r = benchMPSCThroughput(Capacity, numProducers, ItemsPerProducer)
    result.add(r)
    echo formatBenchResult(r)

# ============================================================================
# Burst Workload Benchmark
# ============================================================================

proc benchBurstWorkload(mode: ch.ChannelMode, capacity, numBursts, burstSize: int): BenchResult =
  let chan = ch.newChannel[int](capacity, mode)
  let totalItems = numBursts * burstSize

  let modeStr = if mode == SPSC: "SPSC" else: "MPSC-1P"

  var producerThread: Thread[tuple[chan: Channel[int], bursts: int, size: int]]

  proc burstProducer(args: tuple[chan: Channel[int], bursts: int, size: int]) {.thread.} =
    for burst in 0 ..< args.bursts:
      for i in 0 ..< args.size:
        while not args.chan.trySend(burst * args.size + i):
          discard
      # Small pause between bursts
      for _ in 0 ..< 100: discard

  let t0 = cpuTime()
  createThread(producerThread, burstProducer, (chan, numBursts, burstSize))

  var val: int
  for _ in 0 ..< totalItems:
    while not chan.tryReceive(val):
      discard

  joinThread(producerThread)
  let elapsed = cpuTime() - t0

  BenchResult(
    name: &"{modeStr} burst workload (cap={capacity})",
    items: totalItems,
    duration: elapsed,
    throughputMops: float(totalItems) / elapsed / 1_000_000.0,
    avgLatencyNs: elapsed / float(totalItems) * 1_000_000_000.0
  )

# ============================================================================
# Size Comparison Benchmark
# ============================================================================

proc benchSizeComparison(): seq[BenchResult] =
  result = @[]
  const NumItems = 1_000_000

  echo "\n=== Channel Size Impact ==="
  echo &"{\"Benchmark\":<40} | {\"Items\":>10} | {\"Time\":>8} | {\"Throughput\":>14} | {\"Latency\":>12}"
  echo repeat("=", 100)

  for capacity in [64, 256, 1024, 4096]:
    let r1 = benchSPSCThroughput(capacity, NumItems)
    result.add(r1)
    echo formatBenchResult(r1)

    let r2 = benchMPSCThroughput(capacity, 4, NumItems div 4)
    result.add(r2)
    echo formatBenchResult(r2)

# ============================================================================
# Main Benchmark Suite
# ============================================================================

proc runBenchmarks() =
  echo "\n" & repeat("=", 100)
  echo "nimsync Channel Benchmarks: MPSC vs SPSC"
  echo repeat("=", 100)

  var results: seq[BenchResult] = @[]

  # Throughput benchmarks
  echo "\n=== Throughput Comparison ==="
  echo &"{\"Benchmark\":<40} | {\"Items\":>10} | {\"Time\":>8} | {\"Throughput\":>14} | {\"Latency\":>12}"
  echo repeat("=", 100)

  block:
    let r = benchSPSCThroughput(1024, 1_000_000)
    results.add(r)
    echo formatBenchResult(r)

  for numProducers in [1, 2, 4, 8]:
    let r = benchMPSCThroughput(1024, numProducers, 1_000_000 div numProducers)
    results.add(r)
    echo formatBenchResult(r)

  # Latency benchmarks
  echo "\n=== Latency Comparison ==="
  echo &"{\"Benchmark\":<40} | {\"Items\":>10} | {\"Time\":>8} | {\"Throughput\":>14} | {\"Latency\":>12}"
  echo repeat("=", 100)

  block:
    let r = benchSPSCLatency(128, 10_000)
    results.add(r)
    echo formatBenchResult(r)

  for numProducers in [1, 2, 4]:
    let r = benchMPSCLatency(128, numProducers, 10_000 div numProducers)
    results.add(r)
    echo formatBenchResult(r)

  # Scalability
  results.add(benchMPSCScalability())

  # Size comparison
  results.add(benchSizeComparison())

  # Burst workload
  echo "\n=== Burst Workload ==="
  echo &"{\"Benchmark\":<40} | {\"Items\":>10} | {\"Time\":>8} | {\"Throughput\":>14} | {\"Latency\":>12}"
  echo repeat("=", 100)

  block:
    let r = benchBurstWorkload(SPSC, 256, 1000, 100)
    results.add(r)
    echo formatBenchResult(r)

  block:
    let r = benchBurstWorkload(MPSC, 256, 1000, 100)
    results.add(r)
    echo formatBenchResult(r)

  # Summary
  echo "\n" & repeat("=", 100)
  echo "Benchmark Summary"
  echo repeat("=", 100)
  echo "- SPSC: Optimized for single producer/consumer, uses relaxed atomics"
  echo "- MPSC: Supports multiple concurrent producers via wait-free fetchAdd"
  echo "- Both implementations use cache-line padding to prevent false sharing"
  echo "- Expected performance: 100-200M ops/sec depending on contention"
  echo repeat("=", 100) & "\n"

when isMainModule:
  runBenchmarks()
