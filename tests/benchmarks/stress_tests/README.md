# Async Stress Test Arsenal

This directory contains comprehensive stress tests for nimsync channels, designed to push the library to its breaking point and validate performance under extreme conditions.

## Test Suite Overview

### 1. Goroutine Spawn Storm (`spawn_storm.nim`)
- **Purpose**: Tests channel performance under concurrent access patterns
- **Stress Factors**: Multiple channels, interleaved send/receive operations
- **Adapted From**: Go's `runstress` and Tokio's spawn benchmarks
- **Run**: `nim c -r spawn_storm.nim`

### 2. IO-Bound HTTP Flood (`http_flood.nim`)
- **Purpose**: Tests channels under simulated network/IO load
- **Stress Factors**: High-frequency channel operations with processing delays
- **Adapted From**: TechEmpower benchmarks and Python asyncio stress tests
- **Run**: `nim c -r http_flood.nim`

### 3. Multi-Producer Channel Thrash (`mpmc_thrash.nim`)
- **Purpose**: Tests channel performance under producer/consumer contention
- **Stress Factors**: High message volume, buffer overflow scenarios
- **Adapted From**: Rust Crossbeam and Go channel benchmarks
- **Note**: Currently uses SPSC (MPMC planned for v0.2.0)
- **Run**: `nim c -r mpmc_thrash.nim`

### 4. Backpressure Avalanche (`backpressure_avalanche.nim`)
- **Purpose**: Tests channel behavior when buffer limits are exceeded
- **Stress Factors**: Intentional overflow, bursty traffic patterns
- **Adapted From**: Haskell Streamly and Python semaphore stress tests
- **Run**: `nim c -r backpressure_avalanche.nim`

## Running the Tests

```bash
# Run individual tests
nim c -r tests/benchmarks/stress_tests/spawn_storm.nim
nim c -r tests/benchmarks/stress_tests/http_flood.nim
nim c -r tests/benchmarks/stress_tests/mpmc_thrash.nim
nim c -r tests/benchmarks/stress_tests/backpressure_avalanche.nim

# Or run with performance flags
nim c -d:danger --opt:speed --threads:on --mm:orc -r tests/benchmarks/stress_tests/spawn_storm.nim
```

## Performance Expectations

- **Current Baseline**: 200M+ ops/sec (single-threaded SPSC)
- **Stress Test Goal**: Validate stability under 10x+ load scenarios
- **Failure Indicators**: Crashes, deadlocks, or throughput <50M ops/sec

## Test Results

Record your results here:

### Hardware Configuration
- CPU: [Your CPU]
- Memory: [Your RAM]
- OS: [Your OS]

### Results Summary
| Test | Throughput | Status | Notes |
|------|------------|--------|-------|
| Spawn Storm | | | |
| HTTP Flood | | | |
| MPMC Thrash | | | |
| Backpressure | | | |

## Contributing

When adding new stress tests:
1. Include clear documentation of what stress factors are tested
2. Add performance expectations and failure criteria
3. Follow the existing code patterns
4. Update this README with test details

## Related Files

- `../../../performance_report_v0.1.0.md` - Main performance report
- `../` - Other benchmark tests
- `../../../src/nimsync.nim` - Library implementation