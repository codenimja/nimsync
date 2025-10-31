# Getting Started with nimsync

Welcome to nimsync — a high-performance async runtime for Nim that brings structured concurrency, channels, streams, and actors to your applications.

## Installation

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

### Verify Installation

```nim
import nimsync

echo "nimsync version: ", version()
# Output: nimsync version: 0.1.0
```

## Core Concepts

nimsync is built around four main pillars:

1. **Structured Concurrency** - TaskGroups ensure proper cleanup
2. **Channels** - Type-safe message passing between tasks
3. **Streams** - Backpressure-aware data flow
4. **Actors** - Stateful concurrent entities

## Your First nimsync Program

Let's start with a simple "Hello, Async World!" example:

```nim
import nimsync
import chronos

proc main() {.async.} =
  echo "🌍 Hello from nimsync!"

  # Use TaskGroup for structured concurrency
  await taskGroup:
    discard g.spawn(proc(): Future[void] {.async.} =
      await sleepAsync(1000.milliseconds)
      echo "✅ Task 1 completed!"
    )

    discard g.spawn(proc(): Future[void] {.async.} =
      await sleepAsync(500.milliseconds)
      echo "✅ Task 2 completed!"
    )

  echo "🎉 All tasks finished!"

when isMainModule:
  waitFor main()
```

**Run it:**
```bash
nim c -r hello_async.nim
```

**Output:**
```
🌍 Hello from nimsync!
✅ Task 2 completed!
✅ Task 1 completed!
🎉 All tasks finished!
```

## 🏗️ Structured Concurrency with TaskGroups

TaskGroups ensure that all spawned tasks complete before the group exits:

```nim
import nimsync
import chronos

proc fetchData(id: int): Future[string] {.async.} =
  await sleepAsync((id * 100).milliseconds)
  return fmt"Data {id}"

proc main() {.async.} =
  var results: seq[string] = @[]

  await taskGroup:
    for i in 1..5:
      discard g.spawn(proc(): Future[void] {.async.} =
        let data = await fetchData(i)
        results.add(data)
        echo fmt"📦 Received: {data}"
      )

  echo fmt"✅ Collected {results.len} results"

waitFor main()
```

**Key Benefits:**
- ✅ **Automatic cleanup** - No orphaned tasks
- ✅ **Exception propagation** - Errors bubble up properly
- ✅ **Resource management** - Everything gets cleaned up
- ✅ **Composable** - TaskGroups can be nested

## 📡 Channel Communication

Channels provide type-safe, async message passing:

```nim
import nimsync
import chronos

proc producer(ch: Channel[int]) {.async.} =
  for i in 1..5:
    await ch.send(i)
    echo fmt"📤 Sent: {i}"
  ch.close()

proc consumer(ch: Channel[int]) {.async.} =
  while not ch.closed:
    try:
      let value = await ch.recv()
      echo fmt"📥 Received: {value}"
    except ChannelClosedError:
      break

proc main() {.async.} =
  let channel = newChannel[int](3, ChannelMode.SPSC)  # Buffer size 3

  await taskGroup:
    discard g.spawn(producer(channel))
    discard g.spawn(consumer(channel))

waitFor main()
```

### Channel Types

| Mode | Description | Use Case |
|------|-------------|----------|
| SPSC | Single Producer, Single Consumer | High-performance pipelines |
| MPSC | Multiple Producers, Single Consumer | Work aggregation |
| SPMC | Single Producer, Multiple Consumers | Work distribution |
| MPMC | Multiple Producers, Multiple Consumers | General messaging |

## 🌊 Streams with Backpressure

Streams handle data flow with automatic backpressure management:

```nim
import nimsync
import chronos

proc dataProcessor() {.async.} =
  let stream = initStream[string](BackpressurePolicy.Block)

  await taskGroup:
    # Producer
    discard g.spawn(proc(): Future[void] {.async.} =
      for i in 1..10:
        await stream.send(fmt"Item {i}")
        echo fmt"📤 Produced: Item {i}"
        await sleepAsync(100.milliseconds)
      stream.close()
    )

    # Consumer
    discard g.spawn(proc(): Future[void] {.async.} =
      while not stream.closed:
        try:
          let item = await stream.receive()
          echo fmt"🔄 Processing: {item}"
          await sleepAsync(200.milliseconds)  # Slow consumer
        except StreamClosedError:
          break
    )

waitFor dataProcessor()
```

### Backpressure Policies

- **Block** - Slow down producer when buffer is full
- **Drop** - Drop new items when buffer is full
- **Spill** - Use overflow buffer (if available)

## 🎭 Actor Pattern

Actors encapsulate state and communicate via messages:

```nim
import nimsync
import chronos

type
  CounterMessage = ref object of Message
    action: string
    value: int

proc counterBehavior(msg: CounterMessage): Future[void] {.async.} =
  static var count = 0

  case msg.action:
  of "increment":
    count += msg.value
    echo fmt"📈 Counter: {count}"
  of "decrement":
    count -= msg.value
    echo fmt"📉 Counter: {count}"
  of "get":
    echo fmt"📊 Current count: {count}"

proc main() {.async.} =
  let system = initActorSystem()
  let counter = system.spawn(counterBehavior)

  # Send messages to actor
  await counter.send(CounterMessage(action: "increment", value: 5))
  await counter.send(CounterMessage(action: "increment", value: 3))
  await counter.send(CounterMessage(action: "decrement", value: 2))
  await counter.send(CounterMessage(action: "get", value: 0))

  await sleepAsync(100.milliseconds)  # Let messages process

waitFor main()
```

## 🔧 Error Handling & Timeouts

nimsync provides powerful error handling primitives:

### Timeouts

```nim
import nimsync
import chronos

proc slowOperation(): Future[string] {.async.} =
  await sleepAsync(5.seconds)
  return "Done!"

proc main() {.async.} =
  try:
    let result = await withTimeout(2.seconds):
      await slowOperation()
    echo result
  except AsyncTimeoutError:
    echo "⏰ Operation timed out!"

waitFor main()
```

### Cancellation

```nim
import nimsync
import chronos

proc main() {.async.} =
  let scope = initCancelScope()

  await taskGroup:
    discard g.spawn(proc(): Future[void] {.async.} =
      try:
        while scope.active:
          echo "🔄 Working..."
          await sleepAsync(500.milliseconds)
      except CancelledError:
        echo "🛑 Task was cancelled"
    )

    discard g.spawn(proc(): Future[void] {.async.} =
      await sleepAsync(2.seconds)
      scope.cancel()
      echo "📢 Cancellation triggered"
    )

waitFor main()
```

## 📊 Performance Tips

### 1. Choose the Right Concurrency Level

```nim
# For I/O bound tasks
await taskGroup:
  for i in 1..100:  # High concurrency OK
    discard g.spawn(ioTask(i))

# For CPU bound tasks
let cpuCores = 4
await taskGroup:
  for i in 1..cpuCores:  # Match CPU cores
    discard g.spawn(cpuTask(i))
```

### 2. Use Appropriate Channel Modes

```nim
# High throughput: SPSC
let fastChannel = newChannel[Data](1000, ChannelMode.SPSC)

# Work distribution: SPMC
let workChannel = newChannel[Task](100, ChannelMode.SPMC)
```

### 3. Buffer Sizes Matter

```nim
# Small buffer for memory efficiency
let memoryChannel = newChannel[BigData](10, ChannelMode.SPSC)

# Large buffer for throughput
let throughputChannel = newChannel[SmallData](10000, ChannelMode.SPSC)
```

## 🔍 Debugging & Monitoring

### Enable Statistics

```bash
nim c -d:statistics -r myapp.nim
```

```nim
import nimsync

# Get performance stats
let stats = getGlobalStats()
echo fmt"Tasks: {stats.totalTasks}, Messages: {stats.totalMessages}"
```

### Performance Benchmarking

```nim
import nimsync

let bench = benchmark()
echo fmt"Channel throughput: {bench.channelThroughput} msgs/sec"
echo fmt"Task overhead: {bench.taskGroupOverhead} ns"
```

## 🚨 Common Pitfalls

### ❌ Don't: Forget TaskGroups

```nim
# BAD: Orphaned tasks
proc badExample() {.async.} =
  discard spawn(longRunningTask())  # Task may be orphaned!
```

```nim
# GOOD: Use TaskGroups
proc goodExample() {.async.} =
  await taskGroup:
    discard g.spawn(longRunningTask())  # Guaranteed cleanup
```

### ❌ Don't: Block in Async Functions

```nim
# BAD: Blocking in async context
proc badAsync() {.async.} =
  sleep(1000)  # Blocks entire thread!
```

```nim
# GOOD: Use async sleep
proc goodAsync() {.async.} =
  await sleepAsync(1.seconds)  # Non-blocking
```

### ❌ Don't: Ignore Channel Closure

```nim
# BAD: No closure handling
while true:
  let msg = await channel.recv()  # Will throw on closure
```

```nim
# GOOD: Handle closure properly
while not channel.closed:
  try:
    let msg = await channel.recv()
    # Process msg
  except ChannelClosedError:
    break
```

## 📚 Next Steps

Now that you understand the basics, explore these areas:

### 🌐 **Real-World Examples**
- [HTTP Client](../examples/http_client/) - Concurrent web requests
- [Echo Server](../examples/echo_server/) - TCP server patterns
- [Chat Server](../examples/chat_server/) - Real-time messaging
- [File Processor](../examples/file_processor/) - Data pipelines
- [Web Scraper](../examples/web_scraper/) - Rate-limited crawling

### 📖 **Advanced Guides**
- [Performance Optimization](./performance.md)
- [Best Practices](./best_practices.md)
- [Architecture Patterns](./patterns.md)
- [Testing Strategies](./testing.md)

### 🔗 **API Reference**
- [Complete API Documentation](../src/htmldocs/nimsync.html)
- [TaskGroup API](../src/htmldocs/nimsync/group.html)
- [Channel API](../src/htmldocs/nimsync/channels.html)
- [Stream API](../src/htmldocs/nimsync/streams.html)
- [Actor API](../src/htmldocs/nimsync/actors.html)

## 🤝 Getting Help

- **GitHub Issues**: [Report bugs or request features](https://github.com/username/nimsync/issues)
- **Discussions**: [Ask questions and share ideas](https://github.com/username/nimsync/discussions)
- **Discord**: Join the [Nim Community Discord](https://discord.gg/nim)

## 🎉 Welcome to nimsync!

You're now ready to build high-performance async applications with structured concurrency!

The key is to:
1. **Start simple** with TaskGroups
2. **Add channels** for communication
3. **Use streams** for data flow
4. **Scale with actors** for complex state

Happy coding! 🚀

---

*For more examples and patterns, check out the [examples directory](../examples/) and [API documentation](../src/htmldocs/nimsync.html).*
