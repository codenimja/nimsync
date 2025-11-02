## Unit tests for MPSC (Multi-Producer Single-Consumer) channel

import std/[atomics, times, strformat]
import ../../../src/private/channel_spsc as ch
import ../../support/test_fixtures

# Alias to avoid conflict with system.Channel
type Channel[T] = ch.Channel[T]

type
  Stats = object
    sent: Atomic[int]
    received: Atomic[int]
    failed: Atomic[int]

proc testBasicMPSC() =
  echo "Testing basic MPSC send/receive..."

  let chan = ch.newChannel[int](16, ch.MPSC)
  assert chan.capacity == 16
  assert chan.isEmpty

  # Single send/receive
  assert chan.trySend(42)
  var val: int
  assert chan.tryReceive(val)
  assert val == 42
  assert chan.isEmpty

  echo "✓ Basic MPSC operations work"

proc testMPSCMultiProducersSingleConsumer() =
  echo "Testing MPSC with 4 producers, 1 consumer..."

  let chan = ch.newChannel[int](1024, ch.MPSC)
  const NumProducers = 4
  const ItemsPerProducer = 10000
  const TotalItems = NumProducers * ItemsPerProducer

  var stats: Stats
  stats.sent.store(0)
  stats.received.store(0)
  stats.failed.store(0)

  # Producer threads
  var producerThreads: array[NumProducers, Thread[tuple[chan: Channel[int], id: int, stats: ptr Stats]]]

  proc producerProc(args: tuple[chan: Channel[int], id: int, stats: ptr Stats]) {.thread.} =
    let start = args.id * ItemsPerProducer
    for i in 0 ..< ItemsPerProducer:
      let val = start + i
      while not args.chan.trySend(val):
        # Spin-wait if full
        discard
      discard args.stats.sent.fetchAdd(1)

  # Start producers
  for i in 0 ..< NumProducers:
    createThread(producerThreads[i], producerProc, (chan, i, stats.addr))

  # Consumer (main thread)
  var received: seq[int] = @[]
  var val: int

  while stats.received.load() < TotalItems:
    if chan.tryReceive(val):
      received.add(val)
      discard stats.received.fetchAdd(1)

  # Wait for producers to finish
  for i in 0 ..< NumProducers:
    joinThread(producerThreads[i])

  # Drain any remaining items
  while chan.tryReceive(val):
    received.add(val)
    discard stats.received.fetchAdd(1)

  assert received.len == TotalItems, "Expected " & $TotalItems & " items, got " & $received.len
  echo "✓ Received all ", TotalItems, " items from ", NumProducers, " producers"

  # Verify all values are present (no duplicates or missing)
  var expected = newSeq[bool](TotalItems)
  for v in received:
    assert v >= 0 and v < TotalItems, "Invalid value: " & $v
    assert not expected[v], "Duplicate value: " & $v
    expected[v] = true

  for i, seen in expected:
    assert seen, "Missing value: " & $i

  echo "✓ All values unique and accounted for"

proc testMPSCStressTest() =
  echo "Testing MPSC stress test (1M items)..."

  let chan = ch.newChannel[int](2048, ch.MPSC)
  const NumProducers = 8
  const ItemsPerProducer = 125000  # 8 * 125k = 1M
  const TotalItems = NumProducers * ItemsPerProducer

  var stats: Stats
  stats.sent.store(0)
  stats.received.store(0)

  let startTime = cpuTime()

  var producerThreads: array[NumProducers, Thread[tuple[chan: Channel[int], id: int, stats: ptr Stats]]]

  proc producerProc(args: tuple[chan: Channel[int], id: int, stats: ptr Stats]) {.thread.} =
    let start = args.id * ItemsPerProducer
    for i in 0 ..< ItemsPerProducer:
      while not args.chan.trySend(start + i):
        discard
      discard args.stats.sent.fetchAdd(1)

  for i in 0 ..< NumProducers:
    createThread(producerThreads[i], producerProc, (chan, i, stats.addr))

  # Consumer
  var count = 0
  var val: int
  while count < TotalItems:
    if chan.tryReceive(val):
      count += 1

  for i in 0 ..< NumProducers:
    joinThread(producerThreads[i])

  let elapsed = cpuTime() - startTime
  let throughput = float(TotalItems) / elapsed / 1_000_000.0

  echo &"✓ Processed {TotalItems} items in {elapsed:.3f}s"
  echo &"  Throughput: {throughput:.2f}M ops/sec"

proc testMPSCFullAndEmpty() =
  echo "Testing MPSC full/empty conditions..."

  let chan = ch.newChannel[int](8, ch.MPSC)

  # Test empty
  assert chan.isEmpty
  assert not chan.isFull
  var val: int
  assert not chan.tryReceive(val)

  # Fill up
  for i in 0 ..< 8:
    assert chan.trySend(i), "Send " & $i & " failed"

  assert chan.isFull
  assert not chan.isEmpty
  assert not chan.trySend(999), "Should reject when full"

  # Drain
  for i in 0 ..< 8:
    assert chan.tryReceive(val), "Receive " & $i & " failed"
    assert val == i

  assert chan.isEmpty
  assert not chan.isFull

  echo "✓ Full/empty detection works correctly"

proc testMPSCBurstWorkload() =
  echo "Testing MPSC with bursty workload..."

  let chan = ch.newChannel[int](256, ch.MPSC)
  const NumProducers = 4
  const NumBursts = 100
  const BurstSize = 50

  var stats: Stats
  stats.sent.store(0)
  stats.received.store(0)

  var producerThreads: array[NumProducers, Thread[tuple[chan: Channel[int], stats: ptr Stats]]]

  proc burstProducer(args: tuple[chan: Channel[int], stats: ptr Stats]) {.thread.} =
    for burst in 0 ..< NumBursts:
      for i in 0 ..< BurstSize:
        while not args.chan.trySend(burst * BurstSize + i):
          discard
        discard args.stats.sent.fetchAdd(1)
      # Small pause between bursts
      for _ in 0 ..< 1000: discard

  for i in 0 ..< NumProducers:
    createThread(producerThreads[i], burstProducer, (chan, stats.addr))

  # Consumer
  const TotalItems = NumProducers * NumBursts * BurstSize
  var val: int
  var count = 0

  while count < TotalItems:
    if chan.tryReceive(val):
      count += 1

  for i in 0 ..< NumProducers:
    joinThread(producerThreads[i])

  assert count == TotalItems
  echo "✓ Handled ", TotalItems, " items in bursty workload"

proc testMPSCLatency() =
  echo "Testing MPSC latency..."

  let chan = ch.newChannel[int](128, ch.MPSC)
  const NumSamples = 10000

  var latencies = newSeq[float](NumSamples)

  # Single producer/consumer for latency measurement
  var producerThread: Thread[Channel[int]]

  proc latencyProducer(c: Channel[int]) {.thread.} =
    for i in 0 ..< NumSamples:
      while not c.trySend(i):
        discard

  createThread(producerThread, latencyProducer, chan)

  var val: int
  for i in 0 ..< NumSamples:
    let t0 = cpuTime()
    while not chan.tryReceive(val):
      discard
    let t1 = cpuTime()
    latencies[i] = (t1 - t0) * 1_000_000_000.0  # nanoseconds

  joinThread(producerThread)

  # Calculate stats
  var sum = 0.0
  var minLat = latencies[0]
  var maxLat = latencies[0]

  for lat in latencies:
    sum += lat
    if lat < minLat: minLat = lat
    if lat > maxLat: maxLat = lat

  let avgLat = sum / float(NumSamples)

  echo &"✓ Latency ({NumSamples} samples):"
  echo &"  Avg: {avgLat:.1f} ns/op"
  echo &"  Min: {minLat:.1f} ns/op"
  echo &"  Max: {maxLat:.1f} ns/op"

when isMainModule:
  echo "\n=== MPSC Channel Unit Tests ==="
  testBasicMPSC()
  testMPSCFullAndEmpty()
  testMPSCMultiProducersSingleConsumer()
  testMPSCBurstWorkload()
  testMPSCStressTest()
  testMPSCLatency()
  echo "\n=== All MPSC tests passed! ===\n"
