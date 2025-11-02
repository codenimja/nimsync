# nimsync

[![CI](https://github.com/codenimja/nimsync/actions/workflows/ci.yml/badge.svg)](https://github.com/codenimja/nimsync/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Nim](https://img.shields.io/badge/nim-2.0.0%2B-yellow.svg?style=flat&logo=nim)](https://nim-lang.org)

**Lock-free SPSC channels for Nim achieving 212M+ ops/sec**

Version 0.2.1 provides production-ready SPSC (Single Producer Single Consumer) channels with world-class performance. This is verified, tested, real code.

## Features

- **212M+ ops/sec** peak throughput (verified on AMD 7950X)
- Lock-free ring buffer with atomic operations
- Zero GC pressure with ORC memory management
- Cache-line aligned (64 bytes) to prevent false sharing
- Power-of-2 sizing for efficient operations
- Non-blocking `trySend`/`tryReceive`
- Async `send`/`recv` wrappers for Chronos

## Installation

### Requirements
- Nim 2.0.0+ (required)
- Chronos 4.0.0+

### From Source
```bash
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install
```

## Quick Start

### Basic Usage
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
Only `ChannelMode.SPSC` is implemented.

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
proc capacity[T](channel: Channel[T]): int
proc isEmpty[T](channel: Channel[T]): bool
proc isFull[T](channel: Channel[T]): bool
```

## Benchmarks

Verified performance on Linux x86_64, Nim 2.2.4, AMD 7950X:

| Metric | Performance |
|--------|-------------|
| Peak throughput | 212,465,682 ops/sec |
| Memory per channel | < 1KB |
| Operation latency | < 100ns |

### Run Yourself
```bash
nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim
./tests/performance/benchmark_spsc
```

## Limitations

1. **SPSC Only** - Single Producer Single Consumer only
   - Each channel: ONE sender, ONE receiver
   - MPSC/SPMC/MPMC will raise `ValueError`

2. **No close()** - Channels don't have close operation
   - Use sentinel values for shutdown signaling

3. **Power-of-2 sizing** - Size rounded up
   - `newChannel[int](10, SPSC)` creates 16-slot channel

4. **Async polling** - `send`/`recv` use exponential backoff polling
   - Starts at 1ms, backs off to 100ms max
   - Use `trySend`/`tryReceive` for zero-latency

## Development

### Testing
```bash
nim c -r tests/unit/test_channel.nim  # Basic tests
nim c -r tests/unit/test_basic.nim    # Version check
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

- **v0.3.0**: Fix and export TaskGroups
- **v0.4.0**: Implement MPSC channels
- **v0.5.0**: Production-ready Streams
- **v1.0.0**: Full async runtime

## Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for complete list. Key issues:

- **Async wrappers use polling** - exponential backoff (1ms-100ms), use `trySend`/`tryReceive` for zero-latency
- **TaskGroup has bugs** - nested async macros fail (not exported)
- **Experimental code incomplete** - actors/streams/scheduler not production-ready

**These are documented bugs, not intentional behavior.** Contributions to fix welcome!

## Contributing

Contributions welcome! Priority areas:
1. Fix TaskGroup nested async bug (blocking v0.3.0)
2. Implement MPSC channels (enables actors)
3. Test and validate Streams
4. Cross-platform support (macOS/Windows)

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for detailed bug list.

## License

MIT License - see LICENSE for details.

---

**Status**: v0.2.1 is honest software. Claims only what's verified (SPSC channels). Documents what's experimental (everything else). Provides roadmap for v1.0.0 when features actually work.

---

## Disclaimer

**nimsync v0.2.1 is research-quality software with one production-ready feature.**

✅ **SPSC channels are real** - 212M+ ops/sec verified, use in production
❌ **Everything else is experimental** - incomplete, buggy, or fake

We document bugs openly. We don't hide incomplete features. We're honest about what works.

**This is not corporate software.** It's a solo developer's work-in-progress. Expectations should match reality.
