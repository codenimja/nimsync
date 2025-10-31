# API Reference

This document provides a comprehensive reference for nimsync's public API. For getting started guides and examples, see the [Getting Started](getting_started.md) documentation.

## Core Modules

### TaskGroup - Structured Concurrency

TaskGroups provide structured concurrency with automatic resource cleanup and error propagation.

```nim
import nimsync

# Basic usage
await taskGroup:
  let task1 = g.spawn(work1())
  let task2 = g.spawn(work2())
  # All tasks complete or get cancelled together

# Error policies
await taskGroup(TaskPolicy.FailFast):     # Cancel all on first error (default)
await taskGroup(TaskPolicy.CollectErrors): # Collect all errors
await taskGroup(TaskPolicy.IgnoreErrors):  # Continue despite errors
```

**Parameters:**
- `policy`: Error handling policy (optional, defaults to `FailFast`)

**Returns:** `Future[void]`

### Channels - Lock-Free Message Passing

Channels provide type-safe, lock-free message passing between tasks.

```nim
# Channel modes
let spsc = initChannel[T](size, ChannelMode.SPSC)  # Single producer, single consumer (fastest)
let mpsc = initChannel[T](size, ChannelMode.MPSC)  # Multi producer, single consumer
let mpmc = initChannel[T](size, ChannelMode.MPMC)  # Multi producer, multi consumer

# Usage
await chan.send(value)
let value = await chan.recv()
chan.close()
```

**Parameters:**
- `T`: Message type
- `size`: Buffer capacity
- `mode`: Channel mode (`SPSC`, `MPSC`, `SPMC`, `MPMC`)

**Methods:**
- `send(value: T)`: Send a message
- `recv(): Future[T]`: Receive a message
- `close()`: Close the channel

### Cancellation - Timeout & Scope Management

Cancellation provides hierarchical timeout and scope management.

```nim
# Timeout operations
await withTimeout(5.seconds):
  await operation()

# Cancellation scopes
await withCancelScope(proc(scope: var CancelScope) {.async.} =
  scope.checkCancelled()  # Throws CancelledError if cancelled
  scope.cancel()          # Cancel this scope
)

# Shield critical sections
await shield:
  await criticalCleanup()  # Won't be cancelled by parent
```

**Functions:**
- `withTimeout(duration, body)`: Execute with timeout
- `withCancelScope(body)`: Execute in cancellable scope
- `shield(body)`: Protect from cancellation

### Streams - Backpressure Control

Streams provide backpressure-aware data flow with combinators.

```nim
# Create stream
var stream = initStream[T](BackpressurePolicy.Block, bufferSize)

# Send/receive
await stream.send(item)
let item = await stream.receive()  # Returns Option[T]

# Batch operations
let batch = await stream.receiveBatch(maxItems)

# Combinators
let doubled = source.map(proc(x: int): int = x * 2)
let filtered = source.filter(proc(x: int): bool = x > 10)
let batched = source.batch(100)
```

**Parameters:**
- `T`: Stream element type
- `policy`: Backpressure policy (`Block`, `Drop`, `Overflow`)
- `bufferSize`: Internal buffer size

**Methods:**
- `send(item: T)`: Send an item
- `receive(): Future[Option[T]]`: Receive an item
- `receiveBatch(maxItems: int)`: Receive multiple items
- `map(transform)`: Transform stream elements
- `filter(predicate)`: Filter stream elements
- `batch(size)`: Batch elements

### Actors - Lightweight Message Passing

Actors provide isolated stateful entities with message processing.

```nim
# Define actor
type MyState = object
  count: int

actorSystem:
  let behavior = actor(MyState(count: 0)):
    handle(IncrementMsg, proc(state: var MyState, msg: IncrementMsg) {.async.} =
      state.count += msg.amount
    )

  let myActor = system.spawn(behavior)
  discard myActor.send(IncrementMsg(amount: 1))
```

**Components:**
- `actorSystem`: Define an actor system
- `actor(initialState)`: Define actor behavior
- `handle(MessageType, handler)`: Define message handlers
- `spawn(behavior)`: Create an actor instance
- `send(message)`: Send message to actor

## Error Handling

```nim
# Structured error handling
withErrorHandling("operation", "component"):
  await riskyOperation()

# Automatic retry
withRetry(maxAttempts = 3, "operation", "component"):
  await unreliableOperation()
```

**Functions:**
- `withErrorHandling(operation, component, body)`: Structured error context
- `withRetry(maxAttempts, operation, component, body)`: Automatic retry logic

## Performance Tips

1. **Use SPSC channels** when possible (fastest)
2. **Batch operations** for high throughput
3. **Check cancellation** in long-running loops
4. **Use memory pools** via `--mm:orc`
5. **Compile with** `-d:release --opt:speed`

## Type Reference

### Enums

```nim
type
  ChannelMode* = enum
    SPSC, MPSC, SPMC, MPMC

  BackpressurePolicy* = enum
    Block, Drop, Overflow

  TaskPolicy* = enum
    FailFast, CollectErrors, IgnoreErrors
```

### Core Types

```nim
type
  TaskGroup* = ref object
  Channel*[T] = ref object
  Stream*[T] = ref object
  Actor*[T] = ref object
  CancelScope* = ref object
```

For complete type definitions and additional APIs, see the source code or generated documentation.