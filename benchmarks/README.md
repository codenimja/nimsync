# nimsync Benchmarks

Official performance benchmarks for nimsync. All results are reproducible and verified in CI.

> **📊 See also**: [nimsync-benchmarks](https://github.com/codenimja/nimsync-benchmarks) repository for community-driven performance comparisons with other frameworks.

## Quick Links

- **🏃 [Run Benchmarks](#running-benchmarks)** - 5-minute verification
- **📋 [Latest Results](#verified-results)** - Current performance numbers
- **🔬 [CI Artifacts](https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml)** - Download automated benchmark runs
- **🧪 Internal Stress Tests** - See `tests/benchmarks/stress_tests/` for validation suite

## Verified Results

**Latest benchmarks** (automated CI + local verification):

### Simple Single-Threaded Benchmark
Location: `tests/performance/benchmark_spsc_simple.nim`

| Metric | Result |
|--------|--------|
| **Peak Throughput** | 600M+ ops/sec |
| **Average Throughput** | 593M+ ops/sec |
| **Latency** | ~1.7 ns/op |

**What this measures**: Raw SPSC channel performance without threading or async overhead.

### Concurrent Async Benchmark
Location: `tests/performance/benchmark_concurrent.nim`

| Metric | Result |
|--------|--------|
| **Peak Throughput** | 512K ops/sec |
| **Average Throughput** | 346K ops/sec |
| **Latency** | ~2000 ns/op |

**What this measures**: Realistic async send/recv with exponential backoff polling (as documented in KNOWN_ISSUES.md).

### Performance Summary

| Benchmark Type | Throughput | Use Case |
|----------------|------------|----------|
| **Simple (trySend/tryReceive)** | 600M+ ops/sec | Maximum performance, tight loops |
| **Async (send/recv)** | 500K ops/sec | Convenience, async/await code |
| **Multi-threaded** | 50M-200M ops/sec | Thread coordination overhead |

### 2. Stress Tests

Validate behavior under extreme conditions and edge cases.

| Test | Scenario | Success Criteria |
|------|----------|------------------|
| **Concurrent Access** | 10 SPSC channels × 10K ops | Maintains >30M ops/sec aggregate |
| **IO Simulation** | Network load patterns | High throughput maintained |
| **Contention** | Multi-producer/consumer | Graceful degradation |
| **Backpressure** | Buffer overflow (16-slot) | Fair scheduling |

### 3. Endurance Tests

Long-running stability validation.

| Test | Duration | Validates |
|------|----------|-----------|
| **24-Hour Run** | 24 hours | Memory leaks, stability |
| **Sustained Load** | 12 hours | Performance consistency |

## Running Benchmarks

### Quick Start (5 minutes)

```bash
# Clone repository
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install -y

# Run simple benchmark (600M+ ops/sec)
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_spsc_simple.nim
./tests/performance/benchmark_spsc_simple

# Run concurrent benchmark (512K ops/sec)  
nim c -r tests/performance/benchmark_concurrent.nim
```

### Expected Results

Performance varies by hardware:

| Hardware Class | Simple Benchmark | Concurrent Benchmark |
|----------------|------------------|---------------------|
| **High-end Desktop (2020+)** | 400M-700M ops/sec | 400K-600K ops/sec |
| **Mid-range Desktop (2018+)** | 200M-500M ops/sec | 200K-400K ops/sec |
| **Laptop** | 100M-300M ops/sec | 100K-300K ops/sec |
| **GitHub CI Runners** | 300M-600M ops/sec | 200K-500K ops/sec |

### View CI Results

Every commit runs automated benchmarks:
1. Go to [Actions → Continuous Benchmarking](https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml)
2. Select a recent run
3. Download `benchmark-results-*` artifacts

## Understanding Results

### Output Format

Benchmark results are saved to multiple locations:

```
benchmarks/
├── reports/
│   ├── benchmark_summary_<timestamp>.md    # Human-readable
│   └── benchmark_results_<timestamp>.csv   # Raw data
├── data/
│   └── run_<timestamp>/                    # Detailed data
└── logs/
    └── bench_<timestamp>.log               # Execution logs
```

### Reading Summary Reports

Each summary includes:

```markdown
# nimsync Benchmark Summary
Date: Fri Oct 31 2025
Nim Version: 2.2.4
nimsync Version: 1.0.0

## Results
- SPSC Throughput: 213,567,459 ops/sec ✅ PASSED
- Task Spawn: 87ns ✅ PASSED
- Memory Usage: 0.94KB ✅ PASSED
```

### Interpreting Metrics

**Throughput** (ops/sec):
- Higher is better
- Compare against target in benchmark code
- Watch for variance across runs

**Latency** (ns/ms):
- Lower is better
- Check p50, p95, p99 percentiles
- Watch for outliers

**Memory**:
- Stable across duration = no leaks
- Gradual growth = investigate
- Spikes = check GC behavior

## Benchmark Environment

### Recommended Hardware

**Minimum**:
- CPU: 2+ cores
- RAM: 4GB
- OS: Linux, macOS, Windows

**Optimal**:
- CPU: 4+ cores, x86_64
- RAM: 8GB+
- OS: Linux (fewer OS scheduling variations)

### Environment Variables

```bash
# Disable CPU frequency scaling (Linux)
sudo cpupower frequency-set -g performance

# Set CPU affinity
taskset -c 0-3 ./benchmark

# Disable turbo boost for consistency
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
```

## Baseline Results

### v1.0.0 (October 31, 2025)

**System**: Linux x86_64, Nim 2.2.4, ORC GC

| Metric | Result | Status |
|--------|--------|--------|
| SPSC Throughput | 213M ops/sec | ✅ 410% of target |
| Task Spawn | < 100ns | ✅ Sub-microsecond |
| Memory/Channel | < 1KB | ✅ Efficient |
| GC Pauses | < 2ms @ 1GB | ✅ Low latency |
| Concurrent Access | 31M ops/sec | ✅ Scales well |
| 24h Stability | 0 leaks | ✅ Production ready |

## Stress Test Details

### Concurrent Access Test

Simulates real-world concurrent channel usage:

```nim
- 10 concurrent SPSC channels
- 10,000 operations per channel
- Measures aggregate throughput
- Target: > 30M ops/sec sustained (aggregate across all channels)
```

### IO-Bound Simulation

Tests backpressure under network-like loads:

```nim
- Simulated network latency
- Variable buffer sizes
- Backpressure policy validation
- Target: Maintain throughput stability
```

### Producer/Consumer Contention

Multi-threaded stress test:

```nim
- 5 producers, 3 consumers
- Shared channels with contention
- Lock-free design validation
- Target: Graceful degradation
```

### Backpressure Avalanche

Extreme buffer overflow scenario:

```nim
- 10,000 operations
- 16-slot buffers (intentionally small)
- Tests overflow handling
- Target: Fair scheduling, no crashes
```

## Writing Benchmarks

### Benchmark Template

```nim
import std/[times, monotimes]
import nimsync

proc benchmarkSpsc() =
  let start = getMonoTime()
  let iterations = 1_000_000
  
  let chan = newChannel[int](1024, ChannelMode.SPSC)
  
  for i in 0..<iterations:
    discard chan.trySend(i)
  
  let duration = getMonoTime() - start
  let opsPerSec = iterations.float / duration.inSeconds()
  
  echo "SPSC Throughput: ", opsPerSec.int, " ops/sec"

when isMainModule:
  benchmarkSpsc()
```

### Best Practices

1. **Warmup**: Run iterations before measuring
2. **Multiple Runs**: Average 3-5 runs minimum
3. **Consistent Environment**: Control CPU scaling, background processes
4. **Clear Metrics**: Report exactly what was measured
5. **Reproducibility**: Document system specs and setup

## Continuous Integration

Benchmarks run automatically in CI:

```yaml
- name: Run benchmarks
  run: nimble bench
  if: matrix.os == 'ubuntu-latest'
  
- name: Upload results
  uses: actions/upload-artifact@v3
  with:
    name: benchmark-results
    path: benchmarks/reports/
```

## Troubleshooting

### Inconsistent Results

**Problem**: Large variance between runs

**Solutions**:
- Disable CPU frequency scaling
- Close background applications
- Use `taskset` for CPU pinning
- Run multiple times, use median

### Lower Than Expected Performance

**Problem**: Not hitting target numbers

**Checklist**:
- [ ] Compiled with `-d:release`
- [ ] Nim 2.0+ (ORC GC)
- [ ] No debug flags enabled
- [ ] Proper CPU architecture flags
- [ ] Not running in VM/container

### Memory Leaks Reported

**Problem**: Memory grows over time

**Debug Steps**:
1. Check if it's actually growing or initial allocation
2. Run with `--gc:orc --passC:-fsanitize=address`
3. Use valgrind/heaptrack for detailed analysis
4. Check for retained references

## Contributing

### Adding Benchmarks

1. Create in `benchmarks/` or `tests/benchmarks/`
2. Follow template structure
3. Document what it measures
4. Add to `Makefile` targets
5. Update this README

### Improving Benchmarks

- Add more realistic scenarios
- Improve measurement accuracy
- Better result reporting
- Cross-platform validation

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## References

### Performance Targets

Based on research and industry standards:

- **SPSC Channels**: 200M+ ops/sec (lock-free design)
- **Task Spawn**: < 100ns (comparable to Tokio)
- **GC Pauses**: < 5ms (ORC GC characteristics)
- **Memory**: < 1KB per primitive (efficient design)

### Comparison Projects

- **Tokio** (Rust): ~100M msgs/sec (bounded channel)
- **Go**: ~30M msgs/sec (buffered channel)
- **Chronos** (Nim): Base async runtime

---

## Quick Command Reference

```bash
# Run all benchmarks
make bench-all

# Performance only
make bench

# Stress tests only
make bench-stress

# View results
make results

# Clean results
make clean-results

# Info
make bench-info
```

---

**Questions?** See [SUPPORT.md](../SUPPORT.md) or open an issue.
