# nimsync Performance Benchmarks

Official benchmark suite following industry best practices from Tokio, Go, and Rust crossbeam.

## Quick Start

```bash
# Run all benchmarks
./tests/performance/run_all_benchmarks.sh

# Or run individually
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_latency.nim
./tests/performance/benchmark_latency
```

## Benchmark Suite

### 1. benchmark_spsc_simple.nim - Throughput (Baseline)
**What it measures**: Raw SPSC channel throughput  
**Industry reference**: Standard practice for lock-free queue benchmarking  
**Results**: 600M+ ops/sec peak, 593M+ average  
**Use case**: Establishes baseline performance

```bash
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_spsc_simple.nim
./tests/performance/benchmark_spsc_simple
```

### 2. benchmark_latency.nim - Latency Distribution
**What it measures**: p50, p95, p99, p99.9 latency percentiles  
**Industry reference**: HdrHistogram approach (Tokio, Netty, Cassandra)  
**Results**: 20ns p50, 31ns p99, 50ns p99.9  
**Use case**: Understand tail latency for latency-sensitive applications

```bash
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_latency.nim
./tests/performance/benchmark_latency
```

**Key metrics**:
- **p50 (median)**: Typical latency
- **p99**: 99% of operations complete within this time
- **p99.9**: Extreme tail latency

### 3. benchmark_burst.nim - Burst Load Patterns
**What it measures**: Performance under bursty workloads  
**Industry reference**: Redis/Memcached burst testing methodology  
**Results**: 408M ops/sec average, 16.6% variance  
**Use case**: Real-world applications have bursty traffic patterns

```bash
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_burst.nim
./tests/performance/benchmark_burst
```

**Key metrics**:
- **Average throughput**: Overall performance
- **Variance**: Stability across different burst sizes (lower is better)

### 4. benchmark_sizes.nim - Buffer Size Optimization
**What it measures**: Impact of channel buffer size on throughput  
**Industry reference**: LMAX Disruptor ring buffer sizing  
**Results**: Finds optimal buffer size for your workload  
**Use case**: Tune channel size for memory vs performance tradeoff

```bash
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_sizes.nim
./tests/performance/benchmark_sizes
```

**Key metrics**:
- **Optimal size**: Best performing buffer size
- **Efficiency curve**: Performance relative to optimal

### 5. benchmark_stress.nim - Maximum Sustainable Load
**What it measures**: System limits and contention rate  
**Industry reference**: Apache JMeter/Gatling stress testing  
**Results**: Identifies breaking point and contention behavior  
**Use case**: Understand system limits before production

```bash
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_stress.nim
./tests/performance/benchmark_stress
```

**Key metrics**:
- **Contention rate**: Failed operations percentage (lower is better)
- **Sustainable throughput**: Maximum load before degradation

### 6. benchmark_sustained.nim - Long-Duration Stability
**What it measures**: Performance consistency over time  
**Industry reference**: Cassandra/ScyllaDB sustained load testing  
**Results**: Verifies no performance degradation  
**Use case**: Detect memory leaks, GC pressure, thermal throttling

```bash
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_sustained.nim
./tests/performance/benchmark_sustained
```

**Key metrics**:
- **Variance**: Stability over time (< 5% is excellent)
- **Min/Max throughput**: Performance envelope

### 7. benchmark_concurrent.nim - Async Performance
**What it measures**: Real async send/recv overhead  
**Industry reference**: Standard async runtime benchmarking  
**Results**: 512K ops/sec (async wrapper overhead)  
**Use case**: Understand cost of convenience (async) vs performance (trySend/tryReceive)

```bash
nim c -r tests/performance/benchmark_concurrent.nim
```

**Key insight**: Channel itself is 600M+ ops/sec, async wrapper adds polling overhead

## Design Principles

✅ **Non-redundant**: Each benchmark measures a different aspect  
✅ **Fast execution**: All complete in <30 seconds  
✅ **Industry standard**: Based on proven methodologies  
✅ **Actionable metrics**: Not just throughput numbers  
✅ **Reproducible**: Clear instructions and minimal variance  

## Benchmark Categories

| Category | Benchmarks | Purpose |
|----------|-----------|---------|
| **Throughput** | simple, concurrent | Raw performance numbers |
| **Latency** | latency | Tail latency analysis |
| **Stability** | burst, sustained | Real-world behavior |
| **Tuning** | sizes | Optimization guidance |
| **Limits** | stress | Breaking point analysis |

## CI Integration

The `benchmark_spsc_simple` runs automatically on every commit via GitHub Actions:
- View results: https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml
- Download artifacts for detailed analysis

## Comparison with Other Systems

To fairly compare with Go channels, Rust crossbeam, etc:

1. **Use same hardware**: Run all tests on same machine
2. **Equivalent operations**: Same send/recv patterns
3. **Release builds**: Go with `-ldflags`, Rust with `--release`
4. **Multiple runs**: Average of 3-5 runs
5. **Report variance**: Include min/max/stddev

See [BENCHMARKING.md](../../BENCHMARKING.md) for detailed comparison guidelines.
