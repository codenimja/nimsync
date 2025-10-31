# Main Test Runner for nimsync

Comprehensive test execution engine with advanced features for complete test suite management.

## Overview

The main test runner (`run_tests.nim`) provides a full-featured test execution environment with:

- **Parallel test execution** for faster runs
- **Advanced performance analytics** and regression detection
- **Comprehensive reporting** with multiple output formats
- **CI/CD integration** with environment-specific configuration
- **Test categorization** and selective execution
- **Resource monitoring** and leak detection
- **Statistical analysis** of performance metrics

## Core Architecture

### Test Discovery and Organization
```nim
type TestSuite* = object
  name*: string
  tests*: seq[TestInfo]
  category*: TestCategory
  priority*: TestPriority

type TestInfo* = object
  name*: string
  file*: string
  category*: TestCategory
  priority*: TestPriority
  timeout*: Duration
  tags*: seq[string]
```

### Execution Engine
```nim
type TestRunner* = object
  config*: RunnerConfig
  results*: seq[TestResult]
  metrics*: PerformanceMetrics
  parallel*: bool
  workers*: int
```

## Command Line Interface

### Basic Usage
```bash
# Run all tests
nim c -r tests/run_tests.nim

# Run with specific configuration
nim c -r tests/run_tests.nim --config:ci

# Run specific categories
nim c -r tests/run_tests.nim --category:unit

# Run with custom options
nim c -r tests/run_tests.nim --parallel --workers:4 --verbose
```

### Command Line Options
```bash
Usage: run_tests [options]

Categories:
  --unit              Run unit tests only
  --integration       Run integration tests only
  --e2e              Run end-to-end tests only
  --performance      Run performance tests only
  --all              Run all categories (default)

Execution:
  --parallel          Enable parallel execution
  --workers:N        Number of worker threads (default: CPU cores)
  --fail-fast         Stop on first failure
  --timeout:SECONDS   Global test timeout
  --retries:N        Retry failed tests N times

Reporting:
  --verbose           Detailed output
  --quiet             Minimal output
  --json              JSON output format
  --junit             JUnit XML output
  --html              HTML report generation
  --coverage          Generate coverage report

Configuration:
  --config:NAME       Load configuration preset
  --env:FILE          Load environment file
  --output:DIR        Output directory for reports

Filtering:
  --pattern:PATTERN   Run tests matching pattern
  --tags:TAGS         Run tests with specific tags
  --exclude:PATTERN   Exclude tests matching pattern

Debugging:
  --debug             Enable debug mode
  --profile           Enable performance profiling
  --trace             Enable execution tracing
```

## Configuration System

### Configuration Presets
```nim
# Predefined configurations
const configs* = {
  "ci": RunnerConfig(
    parallel: true,
    workers: 2,
    failFast: true,
    outputFormat: OutputFormat.Json,
    generateReports: true
  ),
  "dev": RunnerConfig(
    parallel: false,
    verbose: true,
    outputFormat: OutputFormat.Console,
    debug: true
  ),
  "perf": RunnerConfig(
    parallel: true,
    workers: 8,
    outputFormat: OutputFormat.Json,
    performanceMode: true,
    profiling: true
  )
}.toTable
```

### Environment Configuration
```bash
# Environment variables
export TEST_PARALLEL=1
export TEST_WORKERS=4
export TEST_VERBOSE=1
export TEST_FAIL_FAST=1
export TEST_TIMEOUT=300
export TEST_OUTPUT_DIR=./test-results
export TEST_CONFIG=ci
```

### Configuration File
```json
{
  "parallel": true,
  "workers": 4,
  "failFast": false,
  "timeout": 300,
  "outputFormat": "json",
  "categories": ["unit", "integration"],
  "excludePatterns": ["slow_*", "*_stress"],
  "performance": {
    "enabled": true,
    "baselineFile": "performance-baseline.json",
    "regressionThreshold": 0.1
  }
}
```

## Test Categories and Organization

### Test Categories
```nim
type TestCategory* = enum
  Unit           # Individual component tests
  Integration    # Component interaction tests
  E2E           # End-to-end workflow tests
  Performance   # Performance and benchmark tests
  Stress        # Stress and load tests
  Compatibility # Compatibility and regression tests
```

### Test Priorities
```nim
type TestPriority* = enum
  Critical   # Must pass for release
  High       # Important functionality
  Medium     # Standard features
  Low        # Nice-to-have features
```

### Directory Structure
```
tests/
├── unit/              # Unit tests
│   ├── test_basic.nim
│   └── test_utils.nim
├── integration/       # Integration tests
│   ├── test_channels.nim
│   └── test_workflows.nim
├── e2e/              # End-to-end tests
│   ├── test_complete_flow.nim
│   └── test_error_scenarios.nim
├── performance/      # Performance tests
│   ├── test_benchmarks.nim
│   └── test_throughput.nim
└── support/          # Test infrastructure
    ├── async_test_framework.nim
    ├── test_fixtures.nim
    └── simple_runner.nim
```

## Execution Features

### Parallel Execution
```nim
# Automatic worker distribution
let workers = if config.parallel:
  min(config.workers, countProcessors())
else:
  1

# Test distribution across workers
for test in tests:
  let worker = selectWorker(test, workers)
  sendToWorker(worker, test)
```

### Timeout Management
```nim
# Hierarchical timeout system
proc runTestWithTimeout(test: TestInfo): Future[TestResult] {.async.} =
  let timeout = test.timeout or config.defaultTimeout

  try:
    await withTimeout(runTest(test), timeout)
  except TimeoutError:
    return TestResult(
      status: Failed,
      error: "Test timeout exceeded",
      duration: timeout
    )
```

### Resource Monitoring
```nim
type ResourceMonitor* = object
  memory*: MemoryStats
  cpu*: CpuStats
  io*: IoStats

proc monitorTest*(test: TestInfo): TestResult =
  let monitor = startMonitoring()

  let result = runTest(test)

  result.resources = monitor.stop()
  return result
```

## Reporting and Analytics

### Output Formats
```nim
type OutputFormat* = enum
  Console     # Human-readable console output
  Json        # Machine-readable JSON
  Junit       # JUnit XML for CI systems
  Html        # HTML reports with charts
  Csv         # CSV data export
```

### Performance Analytics
```nim
type PerformanceMetrics* = object
  totalDuration*: Duration
  averageDuration*: Duration
  throughput*: float64
  memoryPeak*: int64
  cpuUsage*: float64
  regressions*: seq[Regression]

type Regression* = object
  test*: string
  baseline*: float64
  current*: float64
  change*: float64
  significant*: bool
```

### Report Generation
```nim
proc generateReport*(results: seq[TestResult], format: OutputFormat): string =
  case format
  of Console:
    return generateConsoleReport(results)
  of Json:
    return generateJsonReport(results)
  of Junit:
    return generateJunitReport(results)
  of Html:
    return generateHtmlReport(results)
  of Csv:
    return generateCsvReport(results)
```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Run Unit Tests
  run: nim c -r tests/run_tests.nim --unit --parallel --junit --output:test-results

- name: Run Performance Tests
  run: nim c -r tests/run_tests.nim --performance --config:perf --output:perf-results

- name: Run E2E Tests
  run: nim c -r tests/run_tests.nim --e2e --fail-fast --timeout:600

- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: test-results/
```

### Performance Regression Detection
```yaml
- name: Performance Regression Check
  run: |
    nim c -r tests/run_tests.nim --performance --config:perf --output:current-perf.json

    # Compare with baseline
    if [ -f performance-baseline.json ]; then
      nim r tools/compare_performance.nim current-perf.json performance-baseline.json
    fi

    # Update baseline on main branch
    if [ "$GITHUB_REF" = "refs/heads/main" ]; then
      cp current-perf.json performance-baseline.json
    fi
```

### Coverage Integration
```yaml
- name: Generate Coverage
  run: |
    nim c --passC:-fprofile-arcs --passC:-ftest-coverage -r tests/run_tests.nim --coverage

- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    file: ./coverage/lcov.info
```

## Advanced Features

### Test Dependencies
```nim
# Test dependency management
proc dependsOn*(test: TestInfo, dependency: string) =
  test.dependencies.add(dependency)

# Execution order resolution
proc resolveDependencies*(tests: seq[TestInfo]): seq[TestInfo] =
  # Topological sort based on dependencies
```

### Dynamic Test Generation
```nim
# Generate tests programmatically
proc generateParametrizedTests*(baseTest: TestInfo, params: seq[TestParams]): seq[TestInfo] =
  for param in params:
    let test = baseTest.clone()
    test.name = baseTest.name & "_" & param.name
    test.params = param
    result.add(test)
```

### Custom Test Hooks
```nim
# Global test hooks
proc beforeAll*() =
  setupGlobalResources()

proc afterAll*() =
  cleanupGlobalResources()

proc beforeEach*(test: TestInfo) =
  setupTestEnvironment(test)

proc afterEach*(test: TestInfo) =
  cleanupTestEnvironment(test)
```

## Best Practices

### Configuration Management
```nim
# Use configuration presets for consistency
nim c -r tests/run_tests.nim --config:ci

# Override specific settings as needed
nim c -r tests/run_tests.nim --config:ci --workers:8 --verbose
```

### Performance Testing
```nim
# Dedicated performance runs
nim c -r tests/run_tests.nim --performance --config:perf

# Statistical significance
nim c -r tests/run_tests.nim --performance --retries:5

# Regression monitoring
nim c -r tests/run_tests.nim --performance --baseline:perf-baseline.json
```

### CI/CD Optimization
```nim
# Parallel execution for speed
nim c -r tests/run_tests.nim --parallel --workers:2

# Fail fast for quick feedback
nim c -r tests/run_tests.nim --fail-fast

# Comprehensive reporting
nim c -r tests/run_tests.nim --junit --html --coverage
```

### Debugging and Troubleshooting
```nim
# Debug specific test
nim c -r tests/run_tests.nim --pattern:"failing_test" --debug --trace

# Profile performance
nim c -r tests/run_tests.nim --performance --profile

# Memory leak detection
nim c -r tests/run_tests.nim --pattern:"memory" --verbose
```

## Troubleshooting

### Common Issues
```bash
# Compilation failures
nim c tests/run_tests.nim  # Check for syntax errors

# Test discovery issues
nim c -r tests/run_tests.nim --debug  # See discovery process

# Performance regressions
nim c -r tests/run_tests.nim --performance --baseline:old-results.json

# Resource exhaustion
nim c -r tests/run_tests.nim --workers:1 --timeout:600  # Reduce parallelism
```

### Debug Output
```bash
# Maximum debugging
nim c -r tests/run_tests.nim --debug --trace --verbose

# Performance profiling
nim c -r tests/run_tests.nim --performance --profile --output:profile-data

# Memory analysis
nim c -r tests/run_tests.nim --pattern:"memory_*" --verbose --trace
```

This comprehensive test runner provides enterprise-grade test execution capabilities with advanced analytics, parallel processing, and extensive CI/CD integration for robust nimsync testing.