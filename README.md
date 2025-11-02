# nimsync

[![CI](https://github.com/codenimja/nimsync/actions/workflows/ci.yml/badge.svg)](https://github.com/codenimja/nimsync/actions/workflows/ci.yml)
[![Benchmark](https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml/badge.svg)](https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml)
[![Nimble](https://img.shields.io/badge/nimble-v1.1.0-orange.svg)](https://nimble.directory/pkg/nimsync)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Nim](https://img.shields.io/badge/nim-2.0.0%2B-yellow.svg?style=flat&logo=nim)](https://nim-lang.org)
![Peak](https://img.shields.io/badge/peak-615M_ops/sec-success)
![P99](https://img.shields.io/badge/p99_latency-31ns-blue)
![Contention](https://img.shields.io/badge/contention-0%25-brightgreen)

**Lock-free SPSC and MPSC channels for Nim with production-grade performance validation**

nimsync v1.1.0 is production-ready for both SPSC and MPSC channels with comprehensive benchmarking following industry standards (Tokio, Go, LMAX Disruptor, Redis). Performance: 615M ops/sec SPSC peak, 16M ops/sec MPSC (2 producers), 31ns P99 latency, stable under burst loads. This is verified, tested, real code.

## Features

- **High throughput**: 615M ops/sec SPSC (raw), 16M ops/sec MPSC (2 producers), 512K ops/sec (async) - [See benchmarks](#performance)
- **Production-validated**: Comprehensive benchmark suite (throughput, latency, burst, stress, sustained)
- **Industry-standard testing**: Following Tokio, Go, Rust Criterion, LMAX Disruptor methodologies
- **SPSC and MPSC modes**: Single-producer or multi-producer with single consumer
- Lock-free ring buffer with atomic operations
- Zero GC pressure with ORC memory management
- Cache-line aligned (64 bytes) to prevent false sharing
- Wait-free MPSC algorithm (based on dbittman + JCTools patterns)
- Power-of-2 sizing for efficient operations
- Non-blocking `trySend`/`tryReceive`
- Async `send`/`recv` wrappers for Chronos

## Installation

### Requirements
- Nim 2.0.0+ (required)
- Chronos 4.0.0+

### Via Nimble
```bash
nimble install nimsync
```

### From Source
```bash
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install
```

## Quick Start

### Basic Usage (SPSC)
```nim
import nimsync

# Create SPSC channel with 16 slots
let chan = newChannel[int](16, ChannelMode.SPSC)

# Non-blocking operations
if chan.trySend(42):
  echo "Sent successfully"

var value: int
if chan.tryReceive(value):
  echo "Received: ", value
```

### Multi-Producer Usage (MPSC)
```nim
import nimsync
import std/[os, threadpool]

# Create MPSC channel for multiple producers
let chan = newChannel[int](1024, ChannelMode.MPSC)

# Multiple producer threads
proc producer(ch: Channel[int], id: int) =
  for i in 0..<1000:
    while not ch.trySend(id * 1000 + i):
      discard  # Spin until space available

# Start multiple producers
spawn producer(chan, 1)
spawn producer(chan, 2)
spawn producer(chan, 3)

# Single consumer
var count = 0
var value: int
while count < 3000:
  if chan.tryReceive(value):
    echo "Received: ", value
    count.inc

sync()
```

### Async Operations
```nim
import nimsync
import chronos

proc producer(ch: Channel[int]) {.async.} =
  for i in 1..10:
    await ch.send(i)

proc consumer(ch: Channel[int]) {.async.} =
  for i in 1..10:
    let value = await ch.recv()
    echo "Received: ", value

proc main() {.async.} =
  let ch = newChannel[int](16, ChannelMode.SPSC)
  await allFutures([producer(ch), consumer(ch)])

waitFor main()
```

## API Reference

### Channel Creation
```nim
proc newChannel[T](size: int, mode: ChannelMode): Channel[T]
```
Creates a channel with specified size (rounded to next power of 2).

**Modes**:
- `ChannelMode.SPSC`: Single Producer Single Consumer (fastest)
- `ChannelMode.MPSC`: Multi-Producer Single Consumer (wait-free producers)

### Non-Blocking Operations
```nim
proc trySend[T](channel: Channel[T], value: T): bool
proc tryReceive[T](channel: Channel[T], value: var T): bool
```
Returns `true` on success, `false` if channel is full/empty.
**Use these for maximum performance** (sub-100ns operations).

### Async Operations
```nim
proc send[T](channel: Channel[T], value: T): Future[void] {.async.}
proc recv[T](channel: Channel[T]): Future[T] {.async.}
```
Async wrappers using Chronos. **Note**: Uses 1ms polling internally.

### Utilities
```nim
proc isEmpty[T](channel: Channel[T]): bool
proc isFull[T](channel: Channel[T]): bool
```
## Performance

### Comprehensive Benchmark Suite

nimsync includes benchmarks for both SPSC and MPSC modes following industry best practices:

#### SPSC Benchmarks (Single Producer Single Consumer)

| Benchmark | Metric | Result | Industry Reference |
|-----------|--------|--------|--------------------|
| **Throughput** | Peak ops/sec | 615M | Go channels benchmarking |
| **Latency** | p50/p99/p99.9 | 30ns/31ns/31ns | Tokio/Cassandra percentiles |
| **Burst Load** | Stability | 300M ops/sec, 21% variance | Redis burst testing |
| **Buffer Sizing** | Optimal size | 2048 slots, 559M ops/sec | LMAX Disruptor |
| **Stress Test** | Contention | 0% at 500K ops | JMeter/Gatling |
| **Sustained** | Long-duration | Stable over 10s | Cassandra/ScyllaDB |
| **Async** | Overhead | 512K ops/sec | Standard async benchmarking |

#### MPSC Benchmarks (Multi-Producer Single Consumer)

| Producers | Throughput | Latency (avg) | Notes |
|-----------|-----------|---------------|-------|
| 1P | 33M ops/sec | 30ns | Comparable to SPSC |
| 2P | 16M ops/sec | 62ns | Optimal sweet spot |
| 4P | 9M ops/sec | 111ns | Good scalability |
| 8P | 4M ops/sec | 250ns | Contention limited |

**Key Findings**:
- Wait-free MPSC algorithm: No CAS retry loops
- Best performance: 2 producers (16M ops/sec)
- Stress test: 1M items across 8 producers (5.65M ops/sec)
- Latency stable: 96-117ns across 1-4 producers

### Quick Run
```bash
# Run SPSC benchmark suite (~18 seconds)
./tests/performance/run_all_benchmarks.sh

# Run MPSC benchmarks
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_mpsc.nim
./tests/performance/benchmark_mpsc

# Run individual SPSC benchmarks
nim c -d:danger --opt:speed --mm:orc tests/performance/benchmark_latency.nim
./tests/performance/benchmark_latency
```

**Full Documentation**: See [`tests/performance/README.md`](tests/performance/README.md) for detailed explanations of each benchmark.

### Third-Party Verification

Want to verify these claims yourself?

- **Reproduction Guide**: See [BENCHMARKS.md](BENCHMARKS.md) and [tests/performance/README.md](tests/performance/README.md)
- **CI Benchmarks**: Automatic benchmarks on every commit → [GitHub Actions](https://github.com/codenimja/nimsync/actions/workflows/benchmark.yml)
- **Expected Range**: 20M-600M ops/sec depending on CPU, benchmark type, and system load

## Limitations

1. **Single Consumer Only** - All modes require single consumer
   - SPSC: ONE sender, ONE receiver (fastest)
   - MPSC: MULTIPLE senders, ONE receiver (wait-free)
   - SPMC/MPMC not implemented

2. **No close()** - Channels don't have close operation
   - Use sentinel values for shutdown signaling

3. **Power-of-2 sizing** - Size rounded up
   - `newChannel[int](10, SPSC)` creates 16-slot channel

4. **Async polling** - `send`/`recv` use exponential backoff polling
   - Starts at 1ms, backs off to 100ms max
   - Use `trySend`/`tryReceive` for zero-latency

5. **MPSC contention** - Best performance with 2-4 producers
   - 8+ producers experience diminishing returns due to contention

## Development

### Testing
```bash
nim c -r tests/unit/test_channel.nim              # Basic SPSC tests
nim c -r tests/unit/channels/test_mpsc_channel.nim  # MPSC tests
nim c -r tests/unit/test_basic.nim                # Version check
```

### Benchmarking
```bash
nimble bench  # Run all benchmarks
```

### Code Quality
```bash
nimble fmt   # Format code
nimble lint  # Static analysis
nimble ci    # Full CI checks
```

## Internal/Experimental Code

This repository contains experimental implementations of:
- TaskGroups (structured concurrency)
- Actors (with supervision)
- Streams (backpressure-aware)
- Work-stealing scheduler
- NUMA optimizations

**These are NOT production-ready** and not exported in the public API. They exist as research code for future releases. See internal modules in `src/nimsync/` if interested.

## Roadmap

- ✅ **v1.0.0**: Production SPSC channels (DONE!)
- ✅ **v1.1.0**: MPSC channels (DONE!)
- **v1.2.0**: TaskGroup fixes + Production-ready Streams
- **v2.0.0**: Full async runtime with actors

## Known Issues

See [GitHub Issues](.github/) for experimental features and known limitations:

- **Async wrappers use polling** - exponential backoff (1ms-100ms), use `trySend`/`tryReceive` for zero-latency
- **TaskGroup has bugs** - nested async macros fail (not exported) - [See issue template](.github/ISSUE_TASKGROUP_BUG.md)
- **NUMA untested** - cross-socket performance unknown - [See issue template](.github/ISSUE_NUMA_VALIDATION.md)

**These are documented limitations, not intentional behavior.** Contributions to fix welcome!

## Contributing

Contributions welcome! Priority areas:
1. Fix TaskGroup nested async bug - [Details](.github/ISSUE_TASKGROUP_BUG.md)
2. Validate NUMA performance - [Details](.github/ISSUE_NUMA_VALIDATION.md)
3. Cross-platform support (macOS/Windows)
4. SPMC/MPMC channel implementations

See [issue templates](.github/) for detailed specifications and acceptance criteria.

## License

MIT License - see LICENSE for details.

---

**Status**: Production-ready SPSC and MPSC channels with comprehensive validation. Other features (TaskGroup, actors, streams) are experimental - see [GitHub Issues](.github/) for contributor opportunities.

---

## Disclaimer

**nimsync v1.1.0 is production-ready for SPSC and MPSC channels.**

✅ **SPSC channels verified** - 615M ops/sec peak, 31ns P99 latency, 7-benchmark suite validation
✅ **MPSC channels verified** - 16M ops/sec (2 producers), wait-free algorithm, comprehensive stress testing
⚠️ **Experimental features** - TaskGroup, actors, streams not yet production-ready ([help wanted](.github/))

We document performance honestly. We benchmark rigorously. We're transparent about limitations.

**Open source async runtime built with Nim.** Contributions welcome - see issues for high-impact areas.
