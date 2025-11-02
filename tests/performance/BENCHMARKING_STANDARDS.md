# Benchmarking Standards for nimsync

This document outlines the benchmarking methodology and quality standards for nimsync performance testing, based on industry best practices from Tokio, Go, and Rust ecosystems.

## Benchmark Quality Standards

### 1. Metrics Requirements

Every benchmark must report:

- **Throughput**: Operations per second under steady load
- **Latency Distribution**: p50, p95, p99, p99.9 (not just averages)
- **Variance**: Stability across multiple runs (<20% variance is acceptable)
- **System Context**: CPU, cores, Nim version, compiler flags

### 2. Benchmark Characteristics

All benchmarks must:

- Complete in <60 seconds (preferably <30 seconds)
- Include warmup phase (10-20% of main run)
- Run multiple iterations (minimum 3 for variance calculation)
- Use release builds: `-d:danger --opt:speed --mm:orc`
- Be deterministic (no random behavior without fixed seed)

### 3. Performance Regression Detection

Benchmarks should fail CI if:

- Throughput drops >15% from baseline
- P99 latency increases >25%
- Memory usage increases >30%
- Variance exceeds 30% (indicates instability)

## Industry Standards Applied

### From Tokio (Rust Async Runtime)

**What we adopted**:
- Latency percentile tracking (p50/p95/p99/p99.9)
- Async overhead measurement (raw vs async wrapper)
- Yield budgeting concepts (adapted for Chronos)

**Applied in**: `benchmark_latency.nim`, `benchmark_concurrent.nim`

### From Go Testing Framework

**What we adopted**:
- Benchmark naming convention: `benchmark_*`
- Multiple run sampling for variance
- Simple throughput reporting

**Applied in**: All benchmarks follow Go's `testing.Benchmark` pattern

### From Rust Criterion

**What we adopted**:
- Statistical analysis (percentiles, variance)
- Warmup phases before measurement
- Clear progression (warmup → measure → analyze)

**Applied in**: `benchmark_latency.nim` with percentile calculations

### From LMAX Disruptor

**What we adopted**:
- Ring buffer sizing methodology
- Contention rate measurement
- Efficiency curves relative to optimal

**Applied in**: `benchmark_sizes.nim`

### From Redis/Cassandra Testing

**What we adopted**:
- Burst load pattern testing
- Sustained load stability verification
- Long-duration performance consistency

**Applied in**: `benchmark_burst.nim`, `benchmark_sustained.nim`

## Benchmark Suite Architecture

### Current Implementation

```
tests/performance/
├── Core Benchmarks (Production)
│   ├── benchmark_spsc_simple.nim     # Throughput baseline
│   ├── benchmark_latency.nim         # P99 tail latency
│   ├── benchmark_burst.nim           # Bursty workload patterns
│   ├── benchmark_sizes.nim           # Buffer optimization
│   ├── benchmark_stress.nim          # Breaking point analysis
│   ├── benchmark_sustained.nim       # Stability verification
│   └── benchmark_concurrent.nim      # Async overhead measurement
│
├── Runners
│   └── run_all_benchmarks.sh         # Full suite execution
│
└── Documentation
    ├── README.md                      # Benchmark descriptions
    └── BENCHMARKING_STANDARDS.md      # This file
```

### Design Principles

1. **Non-Redundant**: Each benchmark measures a distinct aspect
2. **Fast Execution**: Total suite runs in ~50 seconds
3. **Clear Output**: Human-readable with actionable insights
4. **Reproducible**: Same hardware → same results (±5%)
5. **CI-Ready**: Automated execution via GitHub Actions

## Compiler Flags Standard

### Release Benchmarks (Default)

```bash
nim c -d:danger --opt:speed --mm:orc --threads:on benchmark.nim
```

- `-d:danger`: Disable all runtime checks
- `--opt:speed`: Optimize for speed over size
- `--mm:orc`: Use ORC memory management
- `--threads:on`: Enable threading support

### Debug Benchmarks (Troubleshooting Only)

```bash
nim c -d:debug --opt:none benchmark.nim
```

**Note**: Debug builds are 10-100x slower - only for correctness validation.

## Variance Analysis

### Acceptable Variance Levels

| Metric | Excellent | Good | Warning | Fail |
|--------|-----------|------|---------|------|
| Throughput | <5% | <15% | <30% | >30% |
| P99 Latency | <10% | <20% | <40% | >40% |
| Memory | <5% | <10% | <25% | >25% |

### Variance Calculation

```nim
proc calculateVariance(results: seq[float64]): float64 =
  let avg = results.sum() / results.len.float64
  let minVal = results.min()
  let maxVal = results.max()
  result = ((maxVal - minVal) / avg) * 100.0
```

## Comparison Guidelines

### Fair Comparison with Other Systems

When comparing nimsync with Go channels, Rust crossbeam, etc:

1. **Same Hardware**: All tests on identical machine
2. **Same Test**: Equivalent send/receive patterns
3. **Release Builds**:
   - Nim: `-d:danger --opt:speed`
   - Rust: `cargo bench --release`
   - Go: `go test -bench . -benchtime=10s`
4. **Multiple Runs**: Minimum 3 runs, report median
5. **Document Everything**: CPU model, clock speed, cache size, RAM speed

### Example Comparison Table

```markdown
| System | Throughput | P99 Latency | Notes |
|--------|------------|-------------|-------|
| nimsync (SPSC) | 600M ops/sec | 31 ns | AMD 7950X, bare metal |
| Tokio (SPSC) | 450M ops/sec | 45 ns | Same hardware |
| Go channels | 180M ops/sec | 120 ns | Same hardware |
```

## Memory Profiling

### Tools

- **Basic**: Track peak memory in benchmark output
- **Advanced**: Use `valgrind` for leak detection
- **Production**: Monitor ORC pause times

### Commands

```bash
# Memory leak detection
nim c --mm:orc --passL:"-lg" benchmark.nim
valgrind --leak-check=full ./benchmark

# Memory profiling
/usr/bin/time -v ./benchmark
```

## CI Integration

### GitHub Actions Workflow

Current implementation runs `benchmark_spsc_simple` on every push:

```yaml
- name: Run SPSC benchmark
  run: |
    nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_spsc_simple.nim
    ./tests/performance/benchmark_spsc_simple
```

### Regression Detection (Future)

Store baseline results, compare on each run:

```bash
# Extract throughput
CURRENT=$(grep "Peak Throughput" results.txt | grep -oP '\d+')
BASELINE=600000000

# Check regression
if [ $CURRENT -lt $((BASELINE * 85 / 100)) ]; then
  echo "Performance regression detected!"
  exit 1
fi
```

## Future Enhancements

### Planned Improvements

1. **Multi-core Scaling**: Test 1, 2, 4, 8, 16 thread performance
2. **Memory Pressure**: Benchmark under constrained memory
3. **CPU Affinity**: Pin threads to specific cores
4. **Flamegraphs**: Generate performance profiles in CI
5. **Historical Tracking**: Store results over time for trend analysis

### Advanced Benchmarks (When Needed)

- **NUMA Awareness**: Multi-socket performance
- **Cache Effects**: L1/L2/L3 sensitivity
- **Thermal Throttling**: Extended high-load behavior
- **Power Efficiency**: Performance per watt

## References

### Industry Standards

- [Tokio Performance Guide](https://tokio.rs/blog/2019-10-scheduler#benchmarking-methodology)
- [Go Benchmark Documentation](https://golang.org/pkg/testing/#hdr-Benchmarks)
- [Rust Criterion.rs](https://github.com/bheisler/criterion.rs)
- [LMAX Disruptor Technical Paper](https://lmax-exchange.github.io/disruptor/)

### Academic References

- "Quantifying Performance Changes with Effect Size Confidence Intervals" (Tomas Kalibera, Richard Jones)
- "Producing Wrong Data Without Doing Anything Obviously Wrong!" (Todd Mytkowicz et al.)

## Summary

nimsync's benchmark suite follows gold-standard practices from production async runtimes. Every benchmark serves a specific purpose, executes quickly, and provides actionable insights. We prioritize reproducibility and clarity over synthetic maximum numbers.

**Key Principle**: Measure what matters in production, not what looks impressive in marketing.
