# Reproducing Benchmark Results

This guide explains how to reproduce nimsync's verified SPSC channel performance.

## Latest Verified Results

**Simple Single-Threaded**: 600M+ ops/sec peak, 593M+ average  
**Concurrent Async**: 512K ops/sec peak, 346K average

These numbers are reproducible on modern hardware (2020+) with the exact commands below.

## Critical Context

Performance varies significantly based on:
- **Benchmark type**: Single-threaded (600M+) vs multi-threaded (50M-200M) vs async (500K)
- **Hardware**: CPU speed, cache size, memory bandwidth
- **System load**: Other processes, virtualization overhead
- **Compiler flags**: Release builds are 10-100x faster than debug

## What You'll Need

- **CPU**: Modern x86_64 (2018+) or ARM64 (M1+)
- **OS**: Linux (tested), macOS (should work), Windows (untested)
- **Nim**: 2.0.0+ (tested on 2.2.4)
- **RAM**: 4GB+ available
- **Time**: 5 minutes for basic verification

## Quick Reproduction (5 Minutes)

### Step 1: Clone and Install

```bash
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install -y
```

### Step 2: Run Simple Benchmark (600M+ ops/sec)

```bash
# Compile with maximum optimization
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_spsc_simple.nim

# Run it
./tests/performance/benchmark_spsc_simple
```

**Expected output**:
```
============================================================
nimsync SPSC Channel Benchmark
============================================================

System Information:
  OS: Linux
  Nim Version: 2.2.4

Peak Throughput: 600,445,855 ops/sec
Average Throughput: 593,827,734 ops/sec
```

### Step 3: Run Concurrent Benchmark (512K ops/sec)

```bash
# Compile and run
nim c -r tests/performance/benchmark_concurrent.nim
```

**Expected output**:
```
Peak Throughput: 512,140 ops/sec
Average Throughput: 346,446 ops/sec
```

## Compiler Flags Explained

- **`-d:danger`**: Disable all runtime checks (bounds, nil, overflow)
- **`--opt:speed`**: Optimize for speed over size  
- **`--mm:orc`**: Use ORC garbage collector (default in Nim 2.x)
- **`-r`**: Compile and run immediately

### 3. Disable CPU Frequency Scaling

```bash
# Set CPU governor to performance mode
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

Turbo boost fluctuations can cause ±20% variance.

### 4. Run with Warmup

```bash
# The benchmark includes automatic warmup
# First 100K iterations are discarded
taskset -c 0 ./benchmark_spsc
```

### 5. Expected Results

| Configuration | Expected Throughput |
|--------------|---------------------|
| Bare metal + CPU pinning + `--d:danger` | **180-220M ops/sec** |
| Bare metal, no pinning | **80-120M ops/sec** |
| VM or Docker | **40-80M ops/sec** |
| Real application (GC pressure) | **50-100M ops/sec** |

## Why Real-World Performance Differs

1. **GC Pressure**: The benchmark sends `int` (8 bytes). Real apps send objects → allocations → GC pauses
2. **Multiple Channels**: Real apps use multiple channels → cache contention
3. **Mixed Workloads**: Real apps do work between send/recv → CPU not dedicated to channel ops
4. **No CPU Pinning**: Production apps don't pin threads → kernel scheduling overhead

## Verification

After running, you should see output like:

```
SPSC Channel Benchmark
======================
Iterations: 10,000,000
Duration: 0.047s
Throughput: 213,567,459 ops/sec
```

If you see < 100M ops/sec, check:
- [ ] CPU pinning enabled (`taskset -c 0`)
- [ ] `--d:danger` flag used
- [ ] Running on bare metal (not VM)
- [ ] Performance CPU governor set
- [ ] No background processes consuming CPU

## Honest Assessment

**nimsync SPSC channels are legitimately fast:**
- Faster than Go buffered channels (~30M ops/sec)
- Competitive with Rust crossbeam (~45M ops/sec unbounded)
- Comparable to C++ Folly SPSC (~200M ops/sec)

**But the 213M number requires:**
- Extreme tuning (CPU pinning, `--d:danger`)
- Ideal hardware (modern AMD/Intel with fast cache)
- Synthetic workload (just send/recv loop, no real work)

**In production, expect 50-100M ops/sec.** Which is still world-class performance.

## Benchmark Source

See: `tests/benchmarks/archive/benchmark_spsc.nim`

The benchmark is intentionally simple:
```nim
for i in 0..<iterations:
  discard chan.trySend(i)
  discard chan.tryReceive(value)
```

No allocation, no GC, no work - pure channel throughput measurement.
