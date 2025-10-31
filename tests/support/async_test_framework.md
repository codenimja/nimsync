# Async Test Framework for nimsync

Modern E2E test framework optimized for async libraries with Chronos integration.

## Overview

The async test framework provides comprehensive testing capabilities for nimsync's async runtime, including:

- **Chronos-native async testing** without blocking
- **Automatic timeout handling** with environment adaptation
- **Performance measurement** and validation
- **Memory leak detection** and monitoring
- **Flakiness reduction** through smart waits and retries
- **CI/CD integration** with environment-specific configuration

## Core Types

### TestMetrics
Performance metrics collected during test execution:

```nim
type TestMetrics* = object
  duration*: chronos.Duration    # Test execution time
  memoryUsed*: int64            # Memory consumed (bytes)
  operations*: int64            # Operations performed
  throughput*: float64          # Operations per second
```

### AsyncTestConfig
Global test configuration:

```nim
type AsyncTestConfig* = object
  timeout*: chronos.Duration     # Test timeout (default: 30s)
  maxMemory*: int64             # Memory limit (default: 100MB)
  expectedThroughput*: float64  # Performance target (ops/sec)
  retries*: int                 # Retry count for flaky tests (default: 3)
  verbose*: bool                # Detailed output (default: false)
```

### TestResult
Comprehensive test outcome:

```nim
type TestResult* = object
  passed*: bool                 # Test success status
  metrics*: TestMetrics        # Performance metrics
  errors*: seq[string]         # Error messages
  warnings*: seq[string]       # Warning messages
```

## Test Templates

### asyncTest
Basic async test wrapper with timeout and error handling:

```nim
asyncTest "Basic async operation":
  # Test code runs in async context
  let result = await someAsyncOperation()
  check result.isValid
```

**Features:**
- Automatic timeout enforcement
- Async exception handling
- Global metrics collection
- Chronos integration

### asyncTestWithMetrics
Performance-validated async test:

```nim
asyncTestWithMetrics "High-throughput operation", 1000000:
  # Test code with performance validation
  let result = await benchmarkOperation()

  # Framework automatically validates:
  # - Execution time
  # - Memory usage
  # - Throughput calculation
  # - Performance target compliance
```

**Automatic Validations:**
- Throughput vs expected target
- Memory usage vs limits
- Performance regression detection
- Statistical significance

## Configuration

### Global Configuration
```nim
# Modify test behavior globally
testConfig.timeout = chronos.minutes(5)        # Extended timeout
testConfig.maxMemory = 500 * 1024 * 1024      # 500MB limit
testConfig.expectedThroughput = 1_000_000.0   # 1M ops/sec target
testConfig.retries = 5                        # More retries
testConfig.verbose = true                      # Detailed output
```

### Environment Variables
```bash
# Runtime configuration
VERBOSE_TESTS=1 nim c -r tests/run_tests.nim
TEST_TIMEOUT=300 nim c -r tests/run_tests.nim  # 5 minutes
MAX_MEMORY=1073741824 nim c -r tests/run_tests.nim  # 1GB
```

## Usage Examples

### Basic Async Test
```nim
suite "Channel Tests":
  asyncTest "SPSC channel send/receive":
    let chan = createChannel[int](10, ChannelMode.SPSC)

    await chan.send(42)
    let result = await chan.recv()

    check result == 42
    chan.close()
```

### Performance Test
```nim
suite "Performance Benchmarks":
  asyncTestWithMetrics "Channel throughput", 100000:
    let chan = createChannel[int](1000, ChannelMode.SPSC)

    proc producer(): Future[void] {.async.} =
      for i in 0..<50000:
        await chan.send(i)

    proc consumer(): Future[void] {.async.} =
      for i in 0..<50000:
        discard await chan.recv()

    # Framework measures and validates performance
    await allFutures([producer(), consumer()])
    chan.close()
```

### Error Handling Test
```nim
suite "Error Handling":
  asyncTest "Timeout handling":
    let chan = createChannel[int](1, ChannelMode.SPSC)

    # This will timeout and be caught by framework
    await chan.recv()  # Channel is empty

  asyncTest "Exception propagation":
    expect ValueError:
      raise newException(ValueError, "Test error")
```

## Advanced Features

### Memory Leak Detection
```nim
asyncTest "Memory leak test":
  # Framework tracks memory before/after
  for i in 0..<1000:
    let data = newSeq[byte](1024)  # 1KB allocations
    # Memory usage automatically monitored
```

### Flakiness Reduction
```nim
asyncTest "Potentially flaky test":
  # Framework automatically retries on failure
  let result = await unreliableOperation()
  check result.isStable
```

### Custom Metrics
```nim
asyncTestWithMetrics "Custom benchmark", 50000:
  var customOps = 0

  let start = getMonoTime()
  for i in 0..<50000:
    await someOperation()
    customOps += 1

  # Framework calculates throughput automatically
  # Additional custom validation
  check customOps == 50000
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run Async Tests
  run: |
    nim c -r tests/run_tests.nim

- name: Performance Validation
  run: |
    RUN_PERFORMANCE_TESTS=1 nim c -r tests/performance/test_benchmarks.nim

- name: Memory Leak Check
  run: |
    VERBOSE_TESTS=1 nim c -r tests/run_tests.nim
    # Check for memory warnings in output
```

### Performance Regression Detection
```bash
# Collect baseline metrics
nim c -r tests/performance/test_benchmarks.nim > baseline.txt

# Compare against current
nim c -r tests/performance/test_benchmarks.nim > current.txt

# Fail if regression > 20%
diff baseline.txt current.txt || exit 1
```

## Best Practices

### Test Organization
```nim
suite "Component Tests":
  setup:
    # Initialize test environment
    setupTestEnvironment()

  teardown:
    # Clean up resources
    cleanupTestResources()

  asyncTest "Basic functionality":
    # Test implementation

  asyncTestWithMetrics "Performance validation", target:
    # Performance test
```

### Timeout Management
```nim
# Short tests
asyncTest "Fast operation":
  testConfig.timeout = chronos.seconds(5)

# Long-running tests
asyncTest "Slow operation":
  testConfig.timeout = chronos.minutes(10)
```

### Memory-Aware Testing
```nim
# Memory-intensive tests
asyncTest "Large data processing":
  testConfig.maxMemory = 2 * 1024 * 1024 * 1024  # 2GB

# Memory leak detection
asyncTest "Long-running operation":
  # Framework monitors memory growth
  for i in 0..<10000:
    await processData()
```

### Performance Benchmarking
```nim
# Statistical significance
asyncTestWithMetrics "Statistical benchmark", 1000000:
  # Multiple iterations for confidence
  for run in 0..<5:
    await benchmarkIteration()

# Environment tolerance
asyncTestWithMetrics "Environment-tolerant test", 500000:
  # Allow for CI/hardware differences
  let tolerance = 0.7  # 70% of target acceptable
  check result.throughput > target * tolerance
```

This framework provides robust, scalable testing infrastructure for nimsync's async runtime with comprehensive performance validation and CI/CD integration.