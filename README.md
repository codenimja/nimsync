# nimsync

[![CI](https://github.com/codenimja/nimsync/actions/workflows/ci.yml/badge.svg)](https://github.com/codenimja/nimsync/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Nim](https://img.shields.io/badge/nim-2.0.0%2B-yellow.svg?style=flat&logo=nim)](https://nim-lang.org)

**Production-ready async runtime for Nim featuring structured concurrency, 213M+ ops/sec lock-free channels, and work-stealing scheduler**

> **nimsync** provides three core primitives for building high-performance concurrent applications: **TaskGroups** for structured concurrency, **Channels** for lock-free message passing, and **Streams** for backpressure-aware data processing.

## Table of Contents

- [nimsync](#nimsync)
  - [Table of Contents](#table-of-contents)
  - [Why nimsync?](#why-nimsync)
  - [Features](#features)
  - [Installation](#installation)
    - [Via Nimble](#via-nimble)
    - [From Source](#from-source)
    - [Requirements](#requirements)
  - [Quick Start](#quick-start)
    - [TaskGroup Example](#taskgroup-example)
    - [Channel Example](#channel-example)
    - [Stream Example](#stream-example)
  - [Core API](#core-api)
    - [TaskGroup](#taskgroup)
    - [Channels](#channels)
    - [Streams](#streams)
    - [Actors](#actors)
    - [Scheduler](#scheduler)
    - [Tracing \& Metrics](#tracing--metrics)
    - [Supervision](#supervision)
  - [Benchmarks](#benchmarks)
    - [Stress Test Results](#stress-test-results)
    - [Hardware Specification](#hardware-specification)
    - [Running Benchmarks](#running-benchmarks)
  - [Examples](#examples)
  - [Project Structure](#project-structure)
  - [Documentation](#documentation)
    - [Building Documentation](#building-documentation)
  - [Development](#development)
    - [Setup](#setup)
    - [Available Commands](#available-commands)
    - [Testing Strategy](#testing-strategy)
  - [Known Issues](#known-issues)
    - [Chronos Streams on Nim 1.6.x](#chronos-streams-on-nim-16x)
  - [Contributing](#contributing)
    - [Pull Request Requirements](#pull-request-requirements)
  - [License](#license)

## Why nimsync?

Modern async runtimes for systems programming require three foundational capabilities:

1. **Structured Concurrency**: Ensuring tasks complete or cancel together, preventing resource leaks and orphaned operations
2. **Efficient Message Passing**: Lock-free channels that scale to 200M+ operations per second with predictable latency
3. **Backpressure Management**: Adaptive flow control preventing memory exhaustion under load

**nimsync** is Nim's first async runtime providing all three primitives with zero-cost abstractions and ORC memory safety. Built on Chronos, it extends async/await with production-grade concurrency patterns proven in Rust (Tokio) and Go.

## Features

| **Concurrency** | **Channels** | **Streams** |
|-----------------|-------------|-------------|
| Structured concurrency with TaskGroups | Lock-free SPSC channels | Backpressure-aware streaming |
| Work-stealing scheduler | 213M+ ops/sec throughput | Adaptive policies |
| Cancellation propagation | Zero-copy operations | Buffer management |

| **Actors** | **Scheduler** | **Observability** |
|------------|---------------|------------------|
| Lightweight actor system | NUMA-aware distribution | Built-in metrics |
| Supervision strategies | Adaptive victim selection | Distributed tracing |
| Memory pooling | < 100ns task spawn | Performance counters |

| **Fault Tolerance** | **Core** |
|--------------------|---------| 
| Error isolation | ORC-safe memory model |
| Automatic restarts | Zero-cost abstractions |
| Health monitoring | Thread-safe operations |

## Installation

### Via Nimble

Once published to the Nimble registry:

```bash
nimble install nimsync
```

**Current**: Install directly from GitHub:

```bash
nimble install https://github.com/codenimja/nimsync
```

### From Source

```bash
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install
```

### Requirements

- **Nim**: 2.0.0+
- **Chronos**: 4.0.4+
- **Platforms**: Linux, macOS, Windows

## Quick Start

### TaskGroup Example

```nim
import nimsync
import chronos

proc worker(id: int) {.async.} =
  await sleepAsync(100)
  echo "Worker ", id, " completed"

proc main() {.async.} =
  var group = newTaskGroup()
  
  for i in 1..5:
    group.spawn(worker(i))
  
  await group.wait()  # Wait for all tasks
  echo "All workers finished"

waitFor main()
```

### Channel Example

```nim
import nimsync

proc producer(ch: Channel[int]) {.async.} =
  for i in 1..10:
    await ch.send(i)
  ch.close()

proc consumer(ch: Channel[int]) {.async.} =
  while not ch.closed:
    let value = await ch.recv()
    echo "Received: ", value

proc main() {.async.} =
  let ch = newChannel[int](16)
  
  await allFutures([
    producer(ch),
    consumer(ch)
  ])

waitFor main()
```

### Stream Example

```nim
import nimsync

proc main() {.async.} =
  let stream = newStream[int](BackpressurePolicy.Block)
  
  # Producer
  for i in 1..1000:
    await stream.write(i)
  
  # Consumer with backpressure handling
  await stream
    .map(x => x * 2)
    .filter(x => x mod 4 == 0)
    .forEach(x => echo x)

waitFor main()
```

## Core API

### TaskGroup

Structured concurrency primitive ensuring proper cleanup and error handling:

```nim
import nimsync

proc main() {.async.} =
  var group = newTaskGroup(TaskPolicy.FailFast)
  
  # Spawn concurrent tasks
  group.spawn(longRunningTask())
  group.spawn(anotherTask())
  
  # Wait for completion or first error
  await group.wait()
```

**Features**:
- Zero-allocation task management
- Configurable error policies (`FailFast`, `CollectErrors`, `IgnoreErrors`)
- Automatic cancellation propagation
- NUMA-aware task distribution

### Channels

Lock-free message passing with backpressure support:

```nim
# SPSC (Single Producer Single Consumer)
let spscChan = newChannel[string](1024, ChannelMode.SPSC)

# MPMC support (planned)
let mpmcChan = newChannel[int](512, ChannelMode.MPMC)

# Non-blocking operations
if spscChan.trySend("message"):
  echo "Sent successfully"

var value: string
if spscChan.tryReceive(value):
  echo "Received: ", value

# Async operations with select
select:
  ch1.recv() -> (msg):
    echo "From ch1: ", msg
  ch2.recv() -> (msg):
    echo "From ch2: ", msg
  timeout(1000) -> ():
    echo "Timeout reached"
```

**Performance**: 213M+ ops/sec (SPSC), lock-free atomic operations

### Streams

Backpressure-aware data processing with efficient combinators:

```nim
let stream = newStream[int](BackpressurePolicy.Drop, maxBuffer = 1024)

await stream
  .map(x => x * 2)
  .filter(x => x > 10)
  .batch(100)
  .throttle(rate = 1000, per = 1.seconds)
  .forEach(batch => processBatch(batch))
```

**Backpressure Modes**: `Block`, `Drop`, `DropLatest`, `Unbounded`

### Actors

Lightweight actor system with supervision:

```nim
type Counter = ref object of Actor
  count: int

proc handle(self: Counter, msg: IncrementMsg) {.async.} =
  self.count += msg.value
  
let actor = spawn[Counter]()
await actor.send(IncrementMsg(value: 5))
```

### Scheduler

Work-stealing scheduler optimized for async workloads:

- NUMA-aware thread affinity
- Adaptive victim selection
- < 100ns task spawn overhead
- Configurable worker thread count

### Tracing & Metrics

Built-in observability for production debugging:

```nim
# Enable distributed tracing
enableTracing("my-service")

# Collect metrics
let metrics = getSchedulerMetrics()
echo "Tasks spawned: ", metrics.tasksSpawned
echo "Avg latency: ", metrics.avgLatency

# Performance counters
echo "Channel ops: ", getChannelStats().totalOps
```

### Supervision

Fault-tolerant actor supervision strategies:

```nim
let supervisor = newSupervisor(
  strategy = RestartStrategy.OneForOne,
  maxRestarts = 5,
  within = 30.seconds
)

supervisor.supervise(workerActor)
```

## Benchmarks

Performance validated on **Linux x86_64** with **Nim 2.2.4** and **ORC GC**:

| **Metric** | **Performance** | **Status** |
|-----------|----------------|------------|
| **SPSC Throughput** | **213M ops/sec** | **410% of target** |
| **Task Spawn** | **< 100ns** | **Sub-microsecond** |
| **Memory Usage** | **< 1KB per channel** | **Memory efficient** |
| **GC Pauses** | **< 2ms at 1GB pressure** | **Low latency** |

**Context**: Comparable to Tokio (Rust) and Go's channel performance, with additional type safety from Nim's compile-time guarantees.

### Stress Test Results

| **Test Scenario** | **Throughput** | **Result** |
|------------------|---------------|------------|
| Concurrent Access (10 channels × 10K ops) | 31M ops/sec | ✓ Pass |
| IO-Bound Simulation | High throughput maintained | ✓ Pass |
| Producer/Consumer Contention | Graceful degradation | ✓ Pass |
| Backpressure Avalanche (16-slot buffer) | Fair scheduling | ✓ Pass |

### Hardware Specification
- **CPU**: Linux x86_64
- **Nim Version**: 2.2.4
- **Optimization**: `-d:danger --opt:speed --threads:on --mm:orc`

### Running Benchmarks

```bash
# Performance benchmarks
make bench

# Stress testing suite  
make bench-stress

# Complete benchmark suite
make bench-all

# View latest results
make results
```

**Detailed reports**: [`benchmarks/reports/`](benchmarks/reports/)

## Examples

| **Example** | **Description** | **Command** |
|------------|----------------|-------------|
| **Hello World** | Basic async task | `nim c -r examples/hello/main.nim` |
| **Task Groups** | Structured concurrency | `nim c -r examples/task_group/main.nim` |
| **Channel Select** | Multi-channel operations | `nim c -r examples/channels_select/main.nim` |
| **Backpressure** | Stream flow control | `nim c -r examples/streams_backpressure/main.nim` |
| **Actor Supervision** | Fault-tolerant actors | `nim c -r examples/actors_supervision/main.nim` |
| **Web Framework** | HTTP server integration | `nim c -r examples/web_framework/micro_framework.nim` |
| **Performance Showcase** | Benchmarking example | `nim c -r examples/performance_showcase/main.nim` |

**All examples**: [`examples/`](examples/)

## Project Structure

```
nimsync/
├── src/nimsync/           # Core implementation (4,467 LoC)
│   ├── group.nim         # TaskGroup (363 LoC)
│   ├── channels.nim      # Channel API (130 LoC)
│   ├── streams.nim       # Stream processing (606 LoC)
│   ├── actors.nim        # Actor system
│   ├── scheduler.nim     # Work-stealing scheduler
│   ├── supervision.nim   # Fault tolerance
│   ├── tracing.nim       # Distributed tracing
│   ├── metrics.nim       # Performance monitoring
│   └── backpressure.nim  # Flow control
├── benchmarks/           # Performance validation
│   ├── reports/         # Benchmark results
│   └── stress_tests/    # Extreme load testing
├── tests/               # Comprehensive test suite
│   ├── unit/           # Component tests
│   ├── integration/    # System tests
│   ├── performance/    # Throughput validation
│   └── stress/        # Stability testing
├── examples/           # Usage demonstrations
└── docs/              # Documentation
```

## Documentation

| **Guide** | **Description** |
|-----------|----------------|
| [Getting Started](docs/getting_started.md) | Installation and first steps |
| [API Reference](docs/api.md) | Complete API documentation |
| [Architecture](docs/architecture.md) | System design principles |
| [Performance](docs/performance.md) | Optimization guidelines |
| [Testing](docs/testing.md) | Test strategy and coverage |

### Building Documentation

```bash
nim doc --project --index:on src/nimsync.nim
```

## Development

### Setup

```bash
git clone https://github.com/codenimja/nimsync.git
cd nimsync
nimble install --depsOnly
```

### Available Commands

| **Command** | **Description** |
|------------|----------------|
| `nimble test` | Run basic test suite |
| `nimble bench` | Performance benchmarks |
| `nimble lint` | Code quality checks |
| `nimble fmt` | Format source code |
| `nimble ci` | Complete CI validation |

### Testing Strategy

- **Unit Tests**: 95%+ coverage with isolated component testing
- **Integration**: Cross-module interaction validation  
- **Performance**: Throughput regression prevention
- **Stress**: 24-hour endurance and extreme load testing
- **Memory Safety**: ORC validation and leak detection

## Known Issues

### Chronos Streams on Nim 1.6.x

Stream operations may encounter compatibility issues with Nim 1.6.x and older Chronos versions.

**Workaround**: Upgrade to Nim 2.0+ with Chronos 4.0.4+

```bash
# Recommended versions
nim --version  # 2.0.0+
nimble list chronos  # 4.0.4+
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](docs/CONTRIBUTING.md) for details.

### Pull Request Requirements

- All tests pass (`nimble test`)
- Performance benchmarks validate (`nimble bench`)  
- Documentation updated
- Code formatted (`nimble fmt`)

**Issues**: [GitHub Issues](https://github.com/codenimja/nimsync/issues)  
**Discussions**: [GitHub Discussions](https://github.com/codenimja/nimsync/discussions)

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Links**: [GitHub](https://github.com/codenimja/nimsync) • [Issues](https://github.com/codenimja/nimsync/issues) • [Discussions](https://github.com/codenimja/nimsync/discussions) • [Releases](https://github.com/codenimja/nimsync/releases)