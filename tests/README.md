# nimsync Test Suite Documentation

Complete documentation for the nimsync testing framework and infrastructure.

## Overview

The nimsync test suite provides comprehensive validation of the async runtime library with modern testing practices, performance benchmarking, and extensive CI/CD integration.

## Architecture Overview

### Directory Structure
```
tests/
├── README.md                    # Main documentation
├── run_tests.nim               # Main test runner
├── run_tests.md                # Runner documentation
├── support/                    # Test infrastructure
│   ├── async_test_framework.nim
│   ├── async_test_framework.md
│   ├── test_fixtures.nim
│   ├── test_fixtures.md
│   ├── simple_runner.nim
│   ├── simple_runner.md
│   └── test_template.nim
├── unit/                       # Unit tests (isolated component tests)
│   ├── test_basic.nim
│   ├── test_basic.md
│   ├── test_simple.nim
│   ├── test_simple_core.nim
│   ├── test_simple_coverage.nim
│   ├── test_simple_select.nim
│   ├── cancel/                 # Cancellation tests
│   │   └── test_cancellation.nim
│   ├── channels/               # Channel tests
│   │   ├── test_mpmc_channel.nim
│   │   └── test_spsc_channel.nim
│   └── groups/                 # Task group tests
│       └── test_task_group.nim
├── integration/                # Integration tests (component interactions)
│   ├── test_channels.nim
│   ├── test_taskgroup.nim
│   ├── test_cancelscope.nim
│   ├── test_comprehensive.nim
│   ├── test_core.nim
│   ├── test_errors.nim
│   └── test_select.nim
├── e2e/                        # End-to-end tests (complete workflows)
│   ├── test_complete_workflows.nim
│   └── test_complete_workflows.md
├── performance/                # Performance tests and benchmarks
│   ├── test_benchmarks.nim
│   └── test_benchmarks.md
├── smoke/                      # Quick smoke tests for CI
│   ├── minimal_test.nim
│   └── simple_taskgroup_test.nim
└── stress/                     # Long-running stability tests
    └── stress_test_select.nim
```

### Test Categories

#### Unit Tests (`unit/`)
- **Purpose**: Validate individual components in isolation
- **Scope**: Single functions, classes, and small modules
- **Framework**: unittest with async extensions
- **Coverage**: >90% line coverage target
- **Files**: Basic functionality, simple operations, isolated components

#### Integration Tests (`integration/`)
- **Purpose**: Validate component interactions and cross-cutting concerns
- **Scope**: Multi-component interactions, error handling, select operations
- **Framework**: Async test framework with component orchestration
- **Files**: Channel systems, task groups, cancellation scopes, comprehensive workflows

#### End-to-End Tests (`e2e/`)
- **Purpose**: Validate complete workflow scenarios
- **Scope**: Full user journeys, complex data pipelines, real-world usage patterns
- **Framework**: Async test framework with workflow simulation
- **Files**: Complete workflow orchestration, distributed processing

#### Performance Tests (`performance/`)
- **Purpose**: Measure and validate performance characteristics
- **Scope**: Throughput, latency, memory usage, scalability
- **Framework**: Statistical benchmarking with regression detection
- **Files**: Comprehensive performance analysis and benchmarking

#### Smoke Tests (`smoke/`)
- **Purpose**: Quick validation for CI/CD pipelines
- **Scope**: Basic functionality, critical path validation
- **Framework**: Minimal test framework for fast execution
- **Files**: Minimal tests, simple task group validation

#### Stress Tests (`stress/`)
- **Purpose**: Long-running stability and resource leak detection
- **Scope**: Extended execution, memory pressure, concurrency limits
- **Framework**: Specialized stress testing framework
- **Files**: Select operation stress testing

## Core Components

### Async Test Framework (`support/async_test_framework.nim`)
Modern async testing infrastructure with Chronos integration:

**Key Features:**
- `asyncTest` - Basic async test wrapper with timeout
- `asyncTestWithMetrics` - Performance-validated async tests
- Automatic timeout handling and error propagation
- Memory leak detection and resource monitoring
- CI/CD integration with environment configuration

**Usage:**
```nim
asyncTest "Basic async operation":
  let result = await someAsyncOperation()
  check result.isValid

asyncTestWithMetrics "Performance test", 100000:
  # Framework validates throughput automatically
  await benchmarkOperation()
```

### Test Fixtures (`support/test_fixtures.nim`)
Structured test data generation and environment management:

**Key Features:**
- `TestMessage` and `BenchmarkMessage` types
- Configurable data generation with `generateTestMessage()`
- Environment setup/cleanup with `setupTestEnvironment()`
- Validation helpers for data integrity
- Performance testing fixtures

**Usage:**
```nim
let msg = generateTestMessage(1, 1024, 5)
check validateMessageIntegrity(msg)

let env = setupTestEnvironment()
# ... use environment ...
cleanupTestEnvironment(env)
```

### Test Runners

#### Main Runner (`run_tests.nim`)
Comprehensive test execution with advanced features:

**Capabilities:**
- Parallel test execution
- Multiple output formats (Console, JSON, JUnit, HTML)
- Performance analytics and regression detection
- CI/CD integration with GitHub Actions
- Category-based test selection
- Resource monitoring and profiling

**Usage:**
```bash
# Run all tests
nim c -r tests/run_tests.nim

# Run specific categories
nim c -r tests/run_tests.nim --unit --parallel

# Performance testing
nim c -r tests/run_tests.nim --performance --config:perf
```

#### Simple Runner (`support/simple_runner.nim`)
Lightweight runner for development and CI:

**Capabilities:**
- Quick validation during development
- Simple exit codes for CI integration
- Pattern-based test filtering
- Basic error reporting

**Usage:**
```bash
# Quick validation
nim c -r tests/support/simple_runner.nim

# Specific tests
nim c -r tests/support/simple_runner.nim --pattern:"channel"
```

## Test Execution

### Running Tests

#### Development Workflow
```bash
# Quick smoke tests (fast feedback)
nim c -r tests/smoke/minimal_test.nim

# Full test suite
nim c -r tests/run_tests.nim

# Specific categories
nim c -r tests/run_tests.nim --unit
nim c -r tests/run_tests.nim --integration
nim c -r tests/run_tests.nim --e2e
nim c -r tests/run_tests.nim --performance
nim c -r tests/run_tests.nim --smoke
nim c -r tests/run_tests.nim --stress
```

#### CI/CD Integration
```yaml
- name: Run Smoke Tests
  run: nim c -r tests/smoke/minimal_test.nim

- name: Run Unit Tests
  run: nim c -r tests/run_tests.nim --unit --parallel --junit

- name: Run Integration Tests
  run: nim c -r tests/run_tests.nim --integration --fail-fast

- name: Run E2E Tests
  run: nim c -r tests/run_tests.nim --e2e

- name: Performance Tests
  run: nim c -r tests/run_tests.nim --performance --config:perf
```

### Configuration

#### Environment Variables
```bash
# Test behavior
VERBOSE_TESTS=1
TEST_TIMEOUT=300
MAX_MEMORY=1073741824
TEST_PATTERN="channel"

# CI configuration
CI=true
GITHUB_ACTIONS=true
```

#### Configuration Files
```json
{
  "parallel": true,
  "workers": 4,
  "failFast": false,
  "timeout": 300,
  "categories": ["unit", "integration"],
  "performance": {
    "enabled": true,
    "baselineFile": "performance-baseline.json"
  }
}
```

## Performance Analysis

### Benchmark Categories

#### Throughput Benchmarks
- SPSC/MPMC channel throughput
- Multi-producer/consumer scenarios
- Data pipeline performance

#### Latency Benchmarks
- Send/receive operation latency
- Async operation overhead
- Statistical latency distribution (P95, P99)

#### Memory Benchmarks
- Channel memory overhead
- Memory leak detection
- Memory usage under load

#### Scalability Benchmarks
- Worker count scaling efficiency
- Channel capacity impact
- Concurrent operation performance

### Performance Targets
```nim
const performanceTargets* = {
  "SPSC Throughput": 100_000.0,    # ops/sec
  "MPMC Throughput": 50_000.0,     # ops/sec
  "Average Latency": 10.microseconds,
  "P99 Latency": 100.microseconds,
  "Memory Overhead": 1_048_576,    # 1MB
  "Scaling Efficiency": 0.7         # 70%
}.toTable
```

### Regression Detection
```bash
# Establish baseline
nim c -r tests/run_tests.nim --performance --baseline:perf-baseline.json

# Compare results
nim c -r tests/run_tests.nim --performance --compare:perf-baseline.json

# Fail on significant regression
nim c -r tests/run_tests.nim --performance --regression-threshold:0.05
```

## Quality Assurance

### Test Coverage
- Unit tests for all core components
- Integration tests for component interactions
- E2E tests for complete workflows
- Performance tests for all critical paths

### Code Quality Gates
- Build verification
- Lint/type checking
- Test execution
- Performance regression checks
- Memory leak detection

### CI/CD Pipeline
```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: jiro4989/setup-nim-action@v1

    - name: Run Tests
      run: nim c -r tests/run_tests.nim --parallel --junit

    - name: Performance Tests
      run: nim c -r tests/run_tests.nim --performance --config:perf

    - name: Upload Results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: test-results/
```

## Development Guidelines

### Writing Tests

#### Unit Test Structure
```nim
suite "Component Tests":
  var env: TestEnvironment

  setup:
    env = setupTestEnvironment()

  teardown:
    cleanupTestEnvironment(env)

  asyncTest "Basic functionality":
    # Test implementation
    let result = await component.operation()
    check result.isValid

  asyncTestWithMetrics "Performance validation", target:
    # Performance test
    await benchmarkOperation()
```

#### Integration Test Structure
```nim
suite "Workflow Tests":
  test "End-to-end workflow":
    # Setup pipeline
    let pipeline = createProcessingPipeline()

    # Send test data
    await sendTestData(pipeline.input)

    # Validate results
    let results = await collectResults(pipeline.output)
    check validateWorkflowResults(results)
```

#### Performance Test Structure
```nim
suite "Performance Benchmarks":
  test "Throughput benchmark":
    let chan = createChannel[int](capacity, mode)

    let throughput = await measureThroughput(chan, iterations)
    check throughput > minimumTarget

  test "Latency benchmark":
    let latencies = await measureLatencies(chan, iterations)

    check latencies.p95 < latencyTarget
    check latencies.p99 < latencyTarget
```

### Test Organization
- Group related tests in suites
- Use descriptive test names
- Include setup/teardown for resource management
- Add comments for complex test logic
- Use fixtures for common test data

### Best Practices
- Test one thing per test
- Use descriptive assertions
- Handle async operations properly
- Clean up resources in teardown
- Use appropriate timeouts
- Validate performance requirements

## Troubleshooting

### Common Issues

#### Test Failures
```bash
# Debug specific test
nim c -r tests/run_tests.nim --debug --pattern:"failing_test" --verbose

# Check test isolation
nim c -r tests/support/simple_runner.nim --pattern:"failing_test"
```

#### Performance Issues
```bash
# Profile performance
nim c -r tests/run_tests.nim --performance --profile --pattern:"slow_test"

# Memory analysis
nim c -r tests/run_tests.nim --pattern:"memory" --trace
```

#### Compilation Errors
```bash
# Check syntax
nim c tests/run_tests.nim

# Verbose compilation
nim c -v tests/run_tests.nim
```

### Debug Tools
- `--verbose` for detailed output
- `--debug` for breakpoint support
- `--trace` for execution tracing
- `--profile` for performance profiling
- Environment variables for configuration

## Contributing

### Adding New Tests
1. Choose appropriate category (unit/e2e/performance)
2. Follow existing naming conventions
3. Add comprehensive documentation
4. Include performance requirements where applicable
5. Update CI configuration if needed

### Modifying Test Infrastructure
1. Update documentation for any API changes
2. Maintain backward compatibility
3. Add tests for new functionality
4. Update performance baselines
5. Validate across all supported platforms

### Performance Baseline Updates
1. Run comprehensive performance tests
2. Establish new baselines with `nim c -r tests/run_tests.nim --performance --baseline:new-baseline.json`
3. Update performance targets if justified
4. Document baseline changes

## Support and Resources

### Documentation
- `README.md` - Main test suite documentation
- Component-specific `.md` files for detailed documentation
- Inline code comments for implementation details

### Tools and Scripts
- `run_tests.nim` - Main test runner
- `simple_runner.nim` - Lightweight runner
- `async_test_framework.nim` - Async testing infrastructure
- `test_fixtures.nim` - Test data generation

### CI/CD Resources
- GitHub Actions workflows
- Docker configurations
- Performance monitoring scripts
- Result analysis tools

This comprehensive test suite ensures nimsync maintains high quality, performance, and reliability across all use cases and deployment scenarios.