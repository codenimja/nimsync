# Quick Start

## Installation

```bash
nimble install nimsync
```

## Basic Usage

```nim
import nimsync

# Structured concurrency - tasks auto-cleanup
await taskGroup:
  discard g.spawn(proc() {.async.} = echo "Task 1")
  discard g.spawn(proc() {.async.} = echo "Task 2")

# Cancellation with timeout
await withTimeout(5.seconds):
  await longOperation()

# High-performance channels
let chan = initChannel[int](1000, ChannelMode.SPSC)
await chan.send(42)
let value = await chan.recv()

# Backpressure streams
var stream = initStream[string](BackpressurePolicy.Block)
await stream.send("hello")
let msg = await stream.receive()
```

## Performance Targets

- **Channels (SPSC only)**: 213M msgs/sec peak (bare metal + tuning), 50-100M typical
- **Task spawning**: <100ns overhead
- **Cancellation**: <10ns checking
- **Streams**: >1M items/sec with backpressure

**Note**: MPMC channels are not implemented in v1.0.0.

## Build for Performance

```bash
nim c -d:release --opt:speed your_app.nim
```

See `examples/` for complete working examples.