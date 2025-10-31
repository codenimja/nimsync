# Basic Unit Tests for nimsync

Fundamental unit tests covering core nimsync functionality and basic operations.

## Overview

The basic unit tests (`test_basic.nim`) provide comprehensive validation of nimsync's core components, including:

- **Channel operations** (send, receive, close)
- **Basic synchronization** primitives
- **Error handling** and edge cases
- **Memory management** and resource cleanup
- **Type safety** and generic operations
- **Performance characteristics** of basic operations

## Test Categories

### Channel Operations
Tests for basic channel send/receive functionality:

```nim
suite "Channel Basic Operations":
  test "SPSC channel send/receive":
    let chan = createChannel[int](10, ChannelMode.SPSC)

    # Send operation
    let sendFut = chan.send(42)
    check sendFut.finished

    # Receive operation
    let recvFut = chan.recv()
    check recvFut.finished
    check recvFut.value == 42

    chan.close()

  test "Channel capacity limits":
    let chan = createChannel[int](1, ChannelMode.SPSC)

    # Fill channel to capacity
    check chan.send(1).finished
    check chan.trySend(2) == false  # Should fail

    # Empty channel
    check chan.recv().value == 1
    check chan.tryRecv().isNone  # Should fail

    chan.close()
```

### Synchronization Primitives
Tests for basic sync operations:

```nim
suite "Synchronization Primitives":
  test "Wait group basic usage":
    var wg: WaitGroup
    var counter = 0

    wg.init(2)

    proc worker() {.async.} =
      await sleepAsync(10.milliseconds)
      atomicInc(counter)
      wg.done()

    asyncCheck worker()
    asyncCheck worker()

    wg.wait()
    check counter == 2

  test "Mutex basic locking":
    var mutex: AsyncMutex
    var sharedData = 0

    proc criticalSection(id: int) {.async.} =
      await mutex.acquire()
      sharedData = id
      await sleepAsync(1.millisecond)
      check sharedData == id  # Should not be modified
      mutex.release()

    # Run concurrent operations
    await allFutures([
      criticalSection(1),
      criticalSection(2),
      criticalSection(3)
    ])
```

### Error Handling
Tests for error conditions and edge cases:

```nim
suite "Error Handling":
  test "Channel close during send":
    let chan = createChannel[int](1, ChannelMode.SPSC)

    # Fill channel
    check chan.send(1).finished

    # Close channel
    chan.close()

    # Send should fail
    expect ChannelError:
      discard chan.send(2)

  test "Receive from closed channel":
    let chan = createChannel[int](1, ChannelMode.SPSC)

    # Send and close
    check chan.send(1).finished
    chan.close()

    # Receive should work until empty
    check chan.recv().value == 1

    # Further receives should fail
    expect ChannelError:
      discard chan.recv()

  test "Invalid channel operations":
    let chan = createChannel[int](0, ChannelMode.SPSC)  # Invalid capacity

    expect ValueError:
      discard chan.send(1)
```

### Memory Management
Tests for proper resource cleanup:

```nim
suite "Memory Management":
  test "Channel cleanup":
    # Create channels in loop to test GC
    for i in 0..<1000:
      let chan = createChannel[int](10, ChannelMode.SPSC)
      check chan.send(i).finished
      check chan.recv().value == i
      chan.close()

    # Force GC and check for issues
    GC_fullCollect()

  test "Async operation cleanup":
    var futures: seq[Future[void]]

    proc asyncTask(id: int) {.async.} =
      await sleepAsync(1.millisecond)
      check id >= 0

    # Create many async operations
    for i in 0..<100:
      futures.add(asyncTask(i))

    # Wait for all and cleanup
    await allFutures(futures)
    futures.setLen(0)

    GC_fullCollect()
```

### Type Safety
Tests for generic type handling:

```nim
suite "Type Safety":
  test "Generic channel operations":
    # Test with different types
    let intChan = createChannel[int](5, ChannelMode.SPSC)
    let strChan = createChannel[string](5, ChannelMode.SPSC)
    let objChan = createChannel[ref object](5, ChannelMode.SPSC)

    # Integer operations
    check intChan.send(42).finished
    check intChan.recv().value == 42

    # String operations
    check strChan.send("hello").finished
    check strChan.recv().value == "hello"

    # Object operations
    type TestObj = ref object
      value: int

    let obj = TestObj(value: 123)
    check objChan.send(obj).finished
    check objChan.recv().value.value == 123

    intChan.close()
    strChan.close()
    objChan.close()

  test "Channel type conversion":
    let chan = createChannel[int64](5, ChannelMode.SPSC)

    # Test type compatibility
    check chan.send(42'i64).finished
    check chan.recv().value == 42'i64

    chan.close()
```

## Performance Characteristics

### Basic Performance Tests
```nim
suite "Basic Performance":
  test "Channel throughput":
    let chan = createChannel[int](1000, ChannelMode.SPSC)
    const iterations = 10000

    let start = getMonoTime()

    proc producer() {.async.} =
      for i in 0..<iterations:
        await chan.send(i)

    proc consumer() {.async.} =
      for i in 0..<iterations:
        discard await chan.recv()

    await allFutures([producer(), consumer()])
    chan.close()

    let duration = getMonoTime() - start
    let throughput = iterations.float64 / duration.inMilliseconds.float64 * 1000

    echo &"Throughput: {throughput:.0f} ops/sec"
    check throughput > 10000  # Minimum performance requirement

  test "Memory usage":
    # Test memory efficiency
    let initialMem = getOccupiedMem()

    for i in 0..<1000:
      let chan = createChannel[int](10, ChannelMode.SPSC)
      check chan.send(i).finished
      check chan.recv().value == i
      chan.close()

    let finalMem = getOccupiedMem()
    let memIncrease = finalMem - initialMem

    echo &"Memory increase: {memIncrease} bytes"
    check memIncrease < 1024 * 1024  # Less than 1MB increase
```

## Edge Cases and Boundary Conditions

### Boundary Tests
```nim
suite "Boundary Conditions":
  test "Zero capacity channel":
    expect ValueError:
      let chan = createChannel[int](0, ChannelMode.SPSC)

  test "Maximum capacity channel":
    const maxCap = 1000000
    let chan = createChannel[int](maxCap, ChannelMode.SPSC)

    # Fill to maximum
    for i in 0..<maxCap:
      check chan.trySend(i)

    # Should be full
    check not chan.trySend(maxCap)

    chan.close()

  test "Empty operations":
    let chan = createChannel[int](10, ChannelMode.SPSC)

    # Operations on empty channel
    check chan.tryRecv().isNone
    check chan.empty()

    chan.close()

  test "Concurrent access patterns":
    let chan = createChannel[int](100, ChannelMode.MPMC)
    var results: seq[int]

    proc producer(id: int) {.async.} =
      for i in 0..<10:
        await chan.send(id * 10 + i)

    proc consumer() {.async.} =
      for i in 0..<30:
        let value = await chan.recv()
        results.add(value)

    # Multiple producers and consumers
    await allFutures([
      producer(1), producer(2), producer(3),
      consumer()
    ])

    check results.len == 30
    chan.close()
```

## Test Infrastructure

### Setup and Teardown
```nim
suite "Basic Tests":
  var testEnv: TestEnvironment

  setup:
    testEnv = setupTestEnvironment()

  teardown:
    cleanupTestEnvironment(testEnv)

  # Tests use testEnv for logging, temp files, etc.
```

### Test Utilities
```nim
# Helper procedures for common test patterns
proc waitForChannel[T](chan: Channel[T], timeout: Duration = 1.seconds): Future[T] {.async.} =
  let start = getMonoTime()
  while getMonoTime() - start < timeout:
    let value = chan.tryRecv()
    if value.isSome:
      return value.get
    await sleepAsync(1.millisecond)
  raise newException(TimeoutError, "Channel receive timeout")

proc assertChannelEmpty[T](chan: Channel[T]) =
  check chan.empty()
  check chan.tryRecv().isNone

proc assertChannelFull[T](chan: Channel[T]) =
  # Attempt to send without blocking
  let testValue = default(T)
  check not chan.trySend(testValue)
```

## Running the Tests

### Basic Execution
```bash
# Run all basic tests
nim c -r tests/unit/test_basic.nim

# Run with async test framework
nim c -r tests/run_tests.nim --pattern:"basic"

# Run specific test suite
nim c -r tests/run_tests.nim --pattern:"Channel Basic Operations"
```

### Performance Validation
```bash
# Run performance tests
nim c -r tests/run_tests.nim --performance --pattern:"basic"

# Run with metrics collection
nim c -r tests/run_tests.nim --config:perf --pattern:"Basic Performance"
```

### Debug Mode
```bash
# Debug failing tests
nim c -r tests/run_tests.nim --debug --pattern:"basic" --verbose

# Memory leak detection
nim c -r tests/run_tests.nim --pattern:"Memory Management" --trace
```

## Test Results and Validation

### Success Criteria
- All channel operations work correctly
- Error conditions are handled properly
- Memory usage remains stable
- Performance meets minimum requirements
- Type safety is maintained
- Resource cleanup is complete

### Common Failure Patterns
```nim
# Race conditions in concurrent tests
# Memory leaks in cleanup tests
# Timeout issues in performance tests
# Type conversion errors in generic tests
# Resource exhaustion in boundary tests
```

### Debugging Tips
```nim
# Use --verbose for detailed output
# Use --trace for execution tracing
# Use --debug for breakpoint support
# Check test logs in testEnv.logFile
# Use simple_runner for quick validation
```

These basic unit tests provide fundamental validation of nimsync's core functionality, ensuring reliability and performance of basic operations across all supported use cases.