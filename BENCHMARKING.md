# Benchmarking nimsync

This document explains how to run, verify, and contribute benchmarks for nimsync.

## Quick Start

### Run the Official Benchmark

```bash
# Clone and build
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install -y

# Compile benchmark
nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim

# Run it
./tests/performance/benchmark_spsc
```

### What to Expect

On modern hardware (2020+), you should see:
- **Peak throughput**: 50M-200M+ ops/sec (depending on CPU)
- **Average latency**: 5-20 ns/op
- **Consistency**: Results should be within 10-20% across runs

## Verified Results

### Official Results

Latest verified results (simple single-threaded benchmark):
- **Throughput**: 600M+ ops/sec peak, 593M+ ops/sec average
- **Latency**: ~1.7 ns/op
- **System**: Linux x86_64, Nim 2.2.4
- **Build**: `-d:danger --opt:speed --mm:orc`

Multi-threaded benchmarks show 50M-200M ops/sec due to thread coordination overhead.

### GitHub Actions CI Results

Every commit runs benchmarks on GitHub's infrastructure:
- View results: [GitHub Actions Benchmark Runs](https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml)
- Download artifacts: Each run produces downloadable benchmark reports
- **Expected CI performance**: 50M-150M ops/sec (CI runners are slower than high-end workstations)

## Running Your Own Benchmarks

### Prerequisites

```bash
# Nim 2.0.0+
nim --version

# Install dependencies
nimble install -y chronos
```

### Basic Benchmark

The simplest way to verify performance:

```nim
import nimsync
import std/[monotimes, strformat]

let ch = newChannel[int](1024, ChannelMode.SPSC)
let ops = 10_000_000

let start = getMonoTime()

# Producer/consumer test
var sent = 0
var received = 0
while received < ops:
  if sent < ops and ch.trySend(sent):
    inc sent
  var value: int
  if ch.tryReceive(value):
    inc received

let duration = (getMonoTime() - start).inNanoseconds
let throughput = (ops.float64 / duration.float64) * 1_000_000_000.0

echo fmt"Throughput: {throughput:.0f} ops/sec"
```

### Performance Tips

To get maximum performance:

1. **Use release builds**: `-d:danger --opt:speed`
2. **Enable threading**: `--threads:on`
3. **Use ORC**: `--mm:orc`
4. **Disable profiling**: Remove any `-d:useMalloc` or profiling flags
5. **Run on dedicated hardware**: No VMs, close other applications
6. **Warm up**: Run a quick benchmark first to warm up CPU caches

### Expected Performance by Hardware

**Simple Benchmark** (single-threaded):

| CPU Class | Expected Throughput |
|-----------|-------------------|
| High-end Desktop (2020+) | 400M-700M ops/sec |
| Mid-range Desktop (2018+) | 200M-500M ops/sec |
| Laptop/Mobile | 100M-400M ops/sec |
| GitHub CI Runners | 200M-500M ops/sec |

**Multi-threaded Benchmark** (with thread overhead):

| CPU Class | Expected Throughput |
|-----------|-------------------|
| Server/HEDT (2020+) | 100M-250M ops/sec |
| High-end Desktop (2018+) | 50M-200M ops/sec |
| Mid-range Desktop (2016+) | 30M-150M ops/sec |
| Laptop/Mobile | 20M-100M ops/sec |

*Note*: Results vary significantly based on CPU architecture, clock speed, cache size, and system load. Simple benchmarks are faster because they avoid thread synchronization overhead.

## Comparing with Other Libraries

### Benchmarking Against Go channels

```nim
# nimsync (Nim)
import nimsync
let ch = newChannel[int](1024, ChannelMode.SPSC)
# ... benchmark code ...
```

```go
// Go channels
ch := make(chan int, 1024)
// ... benchmark code ...
```

### Benchmarking Against Rust crossbeam

```nim
# nimsync (Nim)
import nimsync
let ch = newChannel[int](1024, ChannelMode.SPSC)
```

```rust
// Rust crossbeam
use crossbeam_channel::bounded;
let (tx, rx) = bounded(1024);
```

### Fair Comparison Guidelines

For honest comparisons:

1. **Same hardware**: Run all benchmarks on the same machine
2. **Same test**: Use equivalent operations (e.g., 10M send/recv pairs)
3. **Same compiler flags**: Use release/optimized builds for all
4. **Multiple runs**: Report average of 3-5 runs
5. **Report variance**: Include standard deviation or min/max
6. **Document setup**: CPU, OS, compiler versions

## Contributing Benchmark Results

We welcome third-party benchmark results! To contribute:

### 1. Run the Benchmark

```bash
git clone https://github.com/codenimja/nimsync.git
cd nimsync
git checkout v0.2.1  # Use specific version

# Build and run
nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim
./tests/performance/benchmark_spsc > my_results.txt
```

### 2. Collect System Info

```bash
# Linux
uname -a > system_info.txt
lscpu >> system_info.txt
nim --version >> system_info.txt

# macOS
uname -a > system_info.txt
sysctl machdep.cpu.brand_string >> system_info.txt
nim --version >> system_info.txt
```

### 3. Submit Results

Open an issue or PR with:
- Your benchmark results (`my_results.txt`)
- System information (`system_info.txt`)
- Nim/OS versions
- Any notable observations

## Continuous Benchmarking

nimsync uses GitHub Actions for continuous benchmarking:

- **Frequency**: Daily + on every commit
- **Platforms**: Linux (ubuntu-latest), macOS (macos-latest)
- **Nim versions**: stable, devel
- **Artifacts**: Downloadable for 90 days

### Viewing CI Benchmark Results

1. Go to [Actions](https://github.com/codenimja/nimsync/actions)
2. Click on "Continuous Benchmarking" workflow
3. Select a recent run
4. Download artifacts: `benchmark-results-*`

Each artifact contains:
- `benchmark_results.txt`: Raw benchmark output
- `benchmark_report.md`: Formatted report with system info

## Troubleshooting

### Low Performance

If you're seeing < 10M ops/sec:

1. **Check compiler flags**: Must use `-d:danger --opt:speed`
2. **Enable threading**: `--threads:on` is required
3. **Use ORC**: `--mm:orc` for best performance
4. **Check CPU governor**: Should be "performance" not "powersave"
   ```bash
   # Linux: Check current governor
   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

   # Set to performance (requires root)
   echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   ```
5. **Close other apps**: Minimize system load
6. **Run multiple times**: First run may be slower (cache warming)

### Inconsistent Results

If results vary > 30% between runs:

1. **System load**: Check `top` or Activity Monitor
2. **Thermal throttling**: CPU may be overheating
3. **Power management**: Laptop may be on battery saver
4. **Virtualization**: VMs have unpredictable performance

### Benchmark Fails to Compile

```bash
# Install dependencies
nimble install -y

# Check Nim version (need 2.0.0+)
nim --version

# Try verbose compilation
nim c --hints:on --warnings:on -d:danger tests/performance/benchmark_spsc.nim
```

## License

Benchmark code is MIT licensed. Feel free to adapt for your own projects.

## Questions?

- Open an issue: https://github.com/codenimja/nimsync/issues
- Check existing benchmark runs: https://github.com/codenimja/nimsync/actions
