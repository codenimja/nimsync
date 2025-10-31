# Performance Benchmarks for nimsync

Comprehensive performance testing and benchmarking suite for nimsync components.

## Overview

The performance benchmarks (`test_benchmarks.nim`) provide detailed performance analysis and validation of nimsync's core components, including:

- **Throughput measurements** for different channel modes
- **Latency analysis** for various operation types
- **Memory usage profiling** under different loads
- **Scalability testing** with multiple workers
- **Regression detection** against performance baselines
- **Statistical analysis** of performance metrics

## Benchmark Categories

### Throughput Benchmarks
Tests for maximum sustainable throughput:

```nim
suite "Throughput Benchmarks":
  test "SPSC channel throughput":
    const iterations = 1_000_000
    let chan = createChannel[int](1024, ChannelMode.SPSC)

    let start = getMonoTime()

    proc producer() {.async.} =
      for i in 0..<iterations:
        await chan.send(i)

    proc consumer() {.async.} =
      for i in 0..<iterations:
        discard await chan.recv()

    await allFutures([producer(), consumer()])
    chan.close()

    let duration = getMonoTime() - start
    let throughput = iterations.float64 / duration.inSeconds.float64

    echo &"SPSC Throughput: {throughput:.0f} ops/sec"
    check throughput > 100_000  # Minimum requirement

  test "MPMC channel throughput":
    const iterations = 500_000
    const numProducers = 4
    const numConsumers = 4
    let chan = createChannel[int](2048, ChannelMode.MPMC)

    var sent = 0
    var received = 0

    proc producer(id: int) {.async.} =
      for i in 0..<iterations:
        await chan.send(id * iterations + i)
        atomicInc(sent)

    proc consumer(id: int) {.async.} =
      while atomicLoad(received) < (numProducers * iterations):
        discard await chan.recv()
        atomicInc(received)

    let start = getMonoTime()

    var futures: seq[Future[void]]
    for i in 0..<numProducers:
      futures.add(producer(i))
    for i in 0..<numConsumers:
      futures.add(consumer(i))

    await allFutures(futures)
    chan.close()

    let duration = getMonoTime() - start
    let totalOps = numProducers * iterations
    let throughput = totalOps.float64 / duration.inSeconds.float64

    echo &"MPMC Throughput: {throughput:.0f} ops/sec"
    check throughput > 50_000  # Minimum requirement
```

### Latency Benchmarks
Tests for operation latency characteristics:

```nim
suite "Latency Benchmarks":
  test "Channel send/receive latency":
    const iterations = 100_000
    let chan = createChannel[int](1, ChannelMode.SPSC)  # Minimal buffering

    var latencies: seq[Duration]

    proc pingPong() {.async.} =
      for i in 0..<iterations:
        let start = getMonoTime()
        await chan.send(i)
        discard await chan.recv()
        let latency = getMonoTime() - start
        latencies.add(latency)

    await pingPong()
    chan.close()

    # Calculate statistics
    let avgLatency = latencies.sum() div latencies.len
    let p95Latency = latencies.sorted[95 * latencies.len div 100]
    let p99Latency = latencies.sorted[99 * latencies.len div 100]

    echo &"Average latency: {avgLatency.inMicroseconds} μs"
    echo &"P95 latency: {p95Latency.inMicroseconds} μs"
    echo &"P99 latency: {p99Latency.inMicroseconds} μs"

    # Performance requirements
    check avgLatency < 10.microseconds
    check p99Latency < 100.microseconds

  test "Async operation latency":
    const iterations = 50_000
    var latencies: seq[Duration]

    proc asyncOperation() {.async.} =
      for i in 0..<iterations:
        let start = getMonoTime()
        await sleepAsync(0.milliseconds)  # Minimal async operation
        let latency = getMonoTime() - start
        latencies.add(latency)

    await asyncOperation()

    let avgLatency = latencies.sum() div latencies.len
    echo &"Async operation latency: {avgLatency.inNanoseconds} ns"
    check avgLatency < 1000.nanoseconds  # Sub-microsecond requirement
```

### Memory Usage Benchmarks
Tests for memory efficiency and leak detection:

```nim
suite "Memory Benchmarks":
  test "Channel memory usage":
    let initialMem = getOccupiedMem()

    # Create channels of different sizes
    let smallChan = createChannel[int](10, ChannelMode.SPSC)
    let mediumChan = createChannel[int](1000, ChannelMode.SPSC)
    let largeChan = createChannel[int](100000, ChannelMode.SPSC)

    let afterCreationMem = getOccupiedMem()
    let creationOverhead = afterCreationMem - initialMem

    echo &"Channel creation overhead: {creationOverhead} bytes"

    # Test with different data types
    let intChan = createChannel[int](1000, ChannelMode.SPSC)
    let strChan = createChannel[string](1000, ChannelMode.SPSC)
    let objChan = createChannel[ref object](1000, ChannelMode.SPSC)

    # Fill channels
    for i in 0..<1000:
      await intChan.send(i)
      await strChan.send($i)
      await objChan.send((ref object)(value: i))

    let filledMem = getOccupiedMem()
    let dataOverhead = filledMem - afterCreationMem

    echo &"Data storage overhead: {dataOverhead} bytes"

    # Cleanup
    smallChan.close()
    mediumChan.close()
    largeChan.close()
    intChan.close()
    strChan.close()
    objChan.close()

    GC_fullCollect()
    let finalMem = getOccupiedMem()

    echo &"Memory after cleanup: {finalMem} bytes"
    check (finalMem - initialMem) < 1024 * 1024  # Less than 1MB residual

  test "Memory leak detection":
    const iterations = 10_000

    proc memoryStressTest() {.async.} =
      for round in 0..<10:
        var channels: seq[Channel[int]]

        # Create many channels
        for i in 0..<100:
          let chan = createChannel[int](10, ChannelMode.SPSC)
          channels.add(chan)

        # Use channels
        for chan in channels:
          for j in 0..<10:
            await chan.send(j)
            discard await chan.recv()

        # Close channels
        for chan in channels:
          chan.close()

        # Force GC between rounds
        GC_fullCollect()
        let memUsage = getOccupiedMem()
        echo &"Round {round}: {memUsage} bytes"

    await memoryStressTest()

    # Final memory check
    GC_fullCollect()
    let finalMem = getOccupiedMem()
    echo &"Final memory usage: {finalMem} bytes"
```

## Scalability Benchmarks

### Worker Scalability
Tests for performance scaling with worker count:

```nim
suite "Scalability Benchmarks":
  test "Worker scaling efficiency":
    const baseIterations = 100_000
    var results: seq[ScalingResult]

    for workerCount in [1, 2, 4, 8, 16]:
      let chan = createChannel[WorkItem](1000, ChannelMode.MPMC)
      let iterations = baseIterations * workerCount

      proc worker(id: int) {.async.} =
        for i in 0..<baseIterations:
          let item = WorkItem(id: id * baseIterations + i)
          await chan.send(item)

      proc processor() {.async.} =
        var processed = 0
        while processed < iterations:
          discard await chan.recv()
          processed += 1

      let start = getMonoTime()

      var futures: seq[Future[void]]
      for i in 0..<workerCount:
        futures.add(worker(i))
      futures.add(processor())

      await allFutures(futures)
      chan.close()

      let duration = getMonoTime() - start
      let throughput = iterations.float64 / duration.inSeconds.float64

      results.add(ScalingResult(
        workers: workerCount,
        throughput: throughput,
        efficiency: throughput / (results[0].throughput * workerCount.float64)
      ))

    # Analyze scaling efficiency
    for result in results[1..^1]:
      echo &"Workers: {result.workers}, Efficiency: {result.efficiency:.2f}"
      # Should maintain reasonable efficiency
      check result.efficiency > 0.5

  test "Channel capacity scaling":
    var results: seq[CapacityResult]

    for capacity in [1, 10, 100, 1000, 10000]:
      let chan = createChannel[int](capacity, ChannelMode.SPSC)
      const iterations = 100_000

      let start = getMonoTime()

      proc benchmark() {.async.} =
        for i in 0..<iterations:
          await chan.send(i)
          discard await chan.recv()

      await benchmark()
      chan.close()

      let duration = getMonoTime() - start
      let throughput = iterations.float64 / duration.inSeconds.float64

      results.add(CapacityResult(
        capacity: capacity,
        throughput: throughput
      ))

    # Analyze capacity impact
    for result in results:
      echo &"Capacity {result.capacity}: {result.throughput:.0f} ops/sec"
```

## Statistical Analysis

### Performance Distribution Analysis
```nim
suite "Statistical Analysis":
  test "Latency distribution":
    const iterations = 10_000
    let chan = createChannel[int](100, ChannelMode.SPSC)
    var latencies: seq[Duration]

    proc measureLatency() {.async.} =
      for i in 0..<iterations:
        let start = getMonoTime()
        await chan.send(i)
        discard await chan.recv()
        latencies.add(getMonoTime() - start)

    await measureLatency()
    chan.close()

    # Calculate statistical measures
    latencies.sort()
    let mean = latencies.sum() div latencies.len
    let median = latencies[latencies.len div 2]
    let p95 = latencies[95 * latencies.len div 100]
    let p99 = latencies[99 * latencies.len div 100]
    let stdDev = calculateStdDev(latencies, mean)

    echo &"Latency Statistics:"
    echo &"  Mean: {mean.inMicroseconds} μs"
    echo &"  Median: {median.inMicroseconds} μs"
    echo &"  P95: {p95.inMicroseconds} μs"
    echo &"  P99: {p99.inMicroseconds} μs"
    echo &"  StdDev: {stdDev.inMicroseconds} μs"

    # Performance bounds
    check p99 < 1.milliseconds
    check stdDev < mean div 2  # Low variance

  test "Throughput stability":
    const testDuration = 10.seconds
    let chan = createChannel[int](1000, ChannelMode.SPSC)
    var throughputSamples: seq[float64]

    proc continuousLoad() {.async.} =
      let start = getMonoTime()
      var operations = 0

      while getMonoTime() - start < testDuration:
        let batchStart = getMonoTime()
        for i in 0..<1000:  # Batch size
          await chan.send(i)
          discard await chan.recv()
        let batchDuration = getMonoTime() - batchStart
        let batchThroughput = 1000.0 / batchDuration.inSeconds.float64
        throughputSamples.add(batchThroughput)
        operations += 1000

      echo &"Total operations: {operations}"

    await continuousLoad()
    chan.close()

    # Analyze throughput stability
    let avgThroughput = throughputSamples.sum() / throughputSamples.len.float64
    let throughputStdDev = calculateStdDev(throughputSamples, avgThroughput)
    let cv = throughputStdDev / avgThroughput  # Coefficient of variation

    echo &"Throughput Stability:"
    echo &"  Average: {avgThroughput:.0f} ops/sec"
    echo &"  StdDev: {throughputStdDev:.0f} ops/sec"
    echo &"  CV: {cv:.3f}"

    check cv < 0.1  # Low variability requirement
```

## Benchmark Infrastructure

### Benchmark Configuration
```nim
type BenchmarkConfig* = object
  iterations*: int
  warmupIterations*: int
  measurementIterations*: int
  timeout*: Duration
  parallel*: bool
  workers*: int

const defaultConfig* = BenchmarkConfig(
  iterations: 100_000,
  warmupIterations: 10_000,
  measurementIterations: 3,
  timeout: 30.seconds,
  parallel: false,
  workers: 1
)
```

### Result Collection and Analysis
```nim
type BenchmarkResult* = object
  name*: string
  duration*: Duration
  operations*: int64
  throughput*: float64
  latency*: Duration
  memoryUsage*: int64
  cpuUsage*: float64

proc analyzeResults*(results: seq[BenchmarkResult]): BenchmarkAnalysis =
  # Statistical analysis of benchmark results
  let throughputs = results.mapIt(it.throughput)
  let latencies = results.mapIt(it.latency)

  BenchmarkAnalysis(
    avgThroughput: throughputs.sum() / throughputs.len.float64,
    minLatency: latencies.min(),
    maxLatency: latencies.max(),
    p95Latency: latencies.sorted[95 * latencies.len div 100],
    throughputStdDev: calculateStdDev(throughputs, throughputs.sum() / throughputs.len.float64)
  )
```

## Running Benchmarks

### Basic Execution
```bash
# Run all benchmarks
nim c -r tests/performance/test_benchmarks.nim

# Run specific benchmark suite
nim c -r tests/run_tests.nim --performance --pattern:"Throughput"

# Run with detailed output
nim c -r tests/run_tests.nim --performance --verbose

# Run scalability tests
nim c -r tests/run_tests.nim --performance --pattern:"Scalability"
```

### Performance Regression Testing
```bash
# Establish baseline
nim c -r tests/run_tests.nim --performance --baseline:benchmark-baseline.json

# Compare against baseline
nim c -r tests/run_tests.nim --performance --compare:benchmark-baseline.json

# Fail on regression
nim c -r tests/run_tests.nim --performance --regression-threshold:0.05
```

### Profiling and Analysis
```bash
# Memory profiling
nim c -r tests/run_tests.nim --performance --profile --pattern:"Memory"

# CPU profiling
nim c -r tests/run_tests.nim --performance --trace --pattern:"Throughput"

# Statistical analysis
nim c -r tests/run_tests.nim --performance --stats --output:benchmark-stats.json
```

## Performance Requirements

### Minimum Performance Targets
```nim
const performanceTargets* = {
  "SPSC Throughput": 100_000.0,
  "MPMC Throughput": 50_000.0,
  "Average Latency": 10.microseconds,
  "P99 Latency": 100.microseconds,
  "Memory Overhead": 1024 * 1024,  # 1MB
  "Scaling Efficiency": 0.7  # 70% efficiency
}.toTable
```

### Regression Thresholds
```nim
const regressionThresholds* = {
  "throughput": 0.05,  # 5% degradation allowed
  "latency": 0.10,     # 10% increase allowed
  "memory": 0.15       # 15% increase allowed
}.toTable
```

## Benchmark Best Practices

### Measurement Accuracy
- Use sufficient warmup iterations
- Run multiple measurement iterations
- Account for system variability
- Use statistical significance testing

### System Considerations
- Control CPU frequency scaling
- Minimize background processes
- Use consistent hardware
- Account for GC pauses

### Result Interpretation
- Focus on trends over absolute numbers
- Compare relative performance
- Consider statistical significance
- Validate against real-world usage

These performance benchmarks provide comprehensive analysis of nimsync's performance characteristics, ensuring consistent high performance and detecting regressions early in development.