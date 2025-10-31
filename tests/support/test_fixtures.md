# Test Fixtures for nimsync

Comprehensive test data generators and utility functions for reliable testing.

## Overview

The test fixtures module provides structured test data generation and utility functions for nimsync testing, including:

- **Structured message generation** with realistic data patterns
- **Benchmark data creation** with configurable complexity
- **Test environment setup/cleanup** utilities
- **Data validation helpers** for test assertions
- **Performance testing fixtures** with statistical properties

## Core Types

### TestMessage
Structured test message for channel operations:

```nim
type TestMessage* = object
  id*: int64                    # Unique message identifier
  data*: seq[byte]              # Message payload
  timestamp*: chronos.Moment    # Creation timestamp
  priority*: int                # Message priority (0-255)
  flags*: uint32                # Message flags
```

### BenchmarkMessage
Performance testing message with additional metadata:

```nim
type BenchmarkMessage* = object
  base*: TestMessage            # Base message data
  sequence*: int64              # Sequence number for ordering
  batchId*: int64               # Batch identifier
  payloadSize*: int             # Payload size in bytes
  complexity*: float64          # Computational complexity factor
```

### TestEnvironment
Test environment configuration:

```nim
type TestEnvironment* = object
  tempDir*: string              # Temporary directory path
  logFile*: string              # Test log file path
  config*: JsonNode             # Test configuration
  resources*: seq[string]       # Resource paths to cleanup
```

## Data Generators

### generateTestMessage
Generate a single test message with configurable properties:

```nim
proc generateTestMessage*(
  id: int64,
  size: int = 1024,
  priority: int = 0
): TestMessage
```

**Parameters:**
- `id`: Unique message identifier
- `size`: Payload size in bytes (default: 1KB)
- `priority`: Message priority (0-255, default: 0)

**Example:**
```nim
let msg = generateTestMessage(1, 2048, 10)
check msg.id == 1
check msg.data.len == 2048
check msg.priority == 10
```

### generateBenchmarkMessage
Generate performance testing message with complexity:

```nim
proc generateBenchmarkMessage*(
  sequence: int64,
  batchId: int64,
  payloadSize: int = 4096,
  complexity: float64 = 1.0
): BenchmarkMessage
```

**Parameters:**
- `sequence`: Sequence number for ordering
- `batchId`: Batch identifier for grouping
- `payloadSize`: Payload size in bytes (default: 4KB)
- `complexity`: Computational complexity factor (default: 1.0)

**Example:**
```nim
let benchMsg = generateBenchmarkMessage(100, 5, 8192, 2.5)
check benchMsg.sequence == 100
check benchMsg.batchId == 5
check benchMsg.payloadSize == 8192
check benchMsg.complexity == 2.5
```

### generateMessageBatch
Generate a batch of related messages:

```nim
proc generateMessageBatch*(
  startId: int64,
  count: int,
  size: int = 1024
): seq[TestMessage]
```

**Parameters:**
- `startId`: Starting message ID
- `count`: Number of messages to generate
- `size`: Size of each message payload

**Example:**
```nim
let batch = generateMessageBatch(1000, 100, 512)
check batch.len == 100
check batch[0].id == 1000
check batch[99].id == 1099
```

## Environment Management

### setupTestEnvironment
Initialize test environment with temporary resources:

```nim
proc setupTestEnvironment*(): TestEnvironment
```

**Creates:**
- Temporary directory for test artifacts
- Log file for test output
- Configuration file with test settings
- Cleanup tracking for resources

**Example:**
```nim
let env = setupTestEnvironment()
check existsDir(env.tempDir)
check existsFile(env.logFile)
```

### cleanupTestEnvironment
Clean up test environment resources:

```nim
proc cleanupTestEnvironment*(env: var TestEnvironment)
```

**Actions:**
- Removes temporary directory and contents
- Closes and removes log files
- Cleans up any tracked resources
- Resets environment state

**Example:**
```nim
var env = setupTestEnvironment()
# ... use environment ...
cleanupTestEnvironment(env)
check not existsDir(env.tempDir)
```

## Validation Helpers

### validateMessageIntegrity
Validate message data integrity:

```nim
proc validateMessageIntegrity*(msg: TestMessage): bool
```

**Checks:**
- Message ID is valid (> 0)
- Payload data is not empty
- Timestamp is reasonable (not in future)
- Priority is within valid range (0-255)

**Example:**
```nim
let msg = generateTestMessage(1, 1024, 5)
check validateMessageIntegrity(msg)
```

### validateBenchmarkData
Validate benchmark message properties:

```nim
proc validateBenchmarkData*(msg: BenchmarkMessage): bool
```

**Checks:**
- Base message integrity
- Sequence number is valid
- Batch ID is valid
- Payload size matches data length
- Complexity factor is reasonable (> 0)

**Example:**
```nim
let benchMsg = generateBenchmarkMessage(1, 1, 2048, 1.5)
check validateBenchmarkData(benchMsg)
```

### compareMessages
Compare two messages for equality:

```nim
proc compareMessages*(a, b: TestMessage): bool
```

**Comparison:**
- ID equality
- Payload data equality
- Priority equality
- Flags equality (timestamp comparison optional)

**Example:**
```nim
let msg1 = generateTestMessage(1, 1024, 0)
let msg2 = generateTestMessage(1, 1024, 0)
check compareMessages(msg1, msg2)
```

## Performance Testing Fixtures

### generatePerformanceDataset
Generate dataset for performance testing:

```nim
proc generatePerformanceDataset*(
  size: int,
  distribution: DataDistribution = Uniform
): seq[BenchmarkMessage]
```

**Parameters:**
- `size`: Number of messages to generate
- `distribution`: Data size distribution pattern

**Distributions:**
- `Uniform`: All messages same size
- `Normal`: Gaussian size distribution
- `Exponential`: Exponential size distribution

**Example:**
```nim
let dataset = generatePerformanceDataset(1000, Normal)
check dataset.len == 1000
# Validate statistical properties
```

### generateStressTestData
Generate data for stress testing:

```nim
proc generateStressTestData*(
  peakLoad: int,
  duration: chronos.Duration
): seq[BenchmarkMessage]
```

**Parameters:**
- `peakLoad`: Maximum concurrent operations
- `duration`: Test duration

**Features:**
- Time-based message generation
- Load pattern simulation
- Memory pressure testing data

**Example:**
```nim
let stressData = generateStressTestData(10000, chronos.minutes(5))
# Use for stress testing scenarios
```

## Usage Examples

### Basic Test Setup
```nim
suite "Message Tests":
  var env: TestEnvironment

  setup:
    env = setupTestEnvironment()

  teardown:
    cleanupTestEnvironment(env)

  test "Message generation":
    let msg = generateTestMessage(1, 1024, 5)
    check validateMessageIntegrity(msg)
    check msg.priority == 5

  test "Batch generation":
    let batch = generateMessageBatch(100, 50, 512)
    check batch.len == 50
    for i, msg in batch:
      check msg.id == 100 + i
      check msg.data.len == 512
```

### Performance Test Fixtures
```nim
suite "Performance Fixtures":
  test "Benchmark data generation":
    let benchMsg = generateBenchmarkMessage(1, 1, 4096, 2.0)
    check validateBenchmarkData(benchMsg)
    check benchMsg.payloadSize == 4096
    check benchMsg.complexity == 2.0

  test "Performance dataset":
    let dataset = generatePerformanceDataset(1000, Normal)
    check dataset.len == 1000
    # Validate statistical distribution
    let sizes = dataset.mapIt(it.payloadSize)
    check sizes.stdDev > 0  # Non-uniform distribution
```

### Integration Test Setup
```nim
suite "Integration Tests":
  var env: TestEnvironment

  setup:
    env = setupTestEnvironment()
    # Additional setup specific to integration tests

  teardown:
    cleanupTestEnvironment(env)
    # Additional cleanup

  asyncTest "End-to-end message flow":
    let messages = generateMessageBatch(1, 100, 2048)

    # Test full message processing pipeline
    for msg in messages:
      check validateMessageIntegrity(msg)
      # Process message through system
      await processMessage(msg)

    # Validate all messages processed correctly
```

## Best Practices

### Resource Management
```nim
# Always use setup/teardown for resource management
suite "Resource Tests":
  var env: TestEnvironment

  setup:
    env = setupTestEnvironment()

  teardown:
    cleanupTestEnvironment(env)

  test "Resource usage":
    # Use environment resources
    writeFile(env.logFile, "Test log")
    check existsFile(env.logFile)
```

### Data Validation
```nim
# Always validate generated data
test "Data integrity":
  let msg = generateTestMessage(1)
  check validateMessageIntegrity(msg)

  let benchMsg = generateBenchmarkMessage(1, 1)
  check validateBenchmarkData(benchMsg)
```

### Performance Testing
```nim
# Use appropriate fixtures for performance tests
asyncTestWithMetrics "Throughput test", 100000:
  let dataset = generatePerformanceDataset(10000, Uniform)

  # Process dataset and measure performance
  for msg in dataset:
    await processMessage(msg)

  # Framework validates performance metrics
```

### Memory Efficiency
```nim
# Generate data incrementally for large tests
test "Large dataset handling":
  const batchSize = 1000
  var totalMessages = 0

  for batch in 0..<10:
    let messages = generateMessageBatch(
      batch * batchSize, batchSize, 1024
    )
    totalMessages += messages.len
    # Process batch immediately to control memory usage

  check totalMessages == 10000
```

This fixtures module provides reliable, configurable test data generation and environment management for comprehensive nimsync testing.