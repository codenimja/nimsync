# Simple Test Runner for nimsync

Lightweight test execution utility for quick validation and debugging.

## Overview

The simple test runner provides a minimal interface for running nimsync tests with basic reporting, designed for:

- **Quick validation** during development
- **Debugging support** with detailed error output
- **CI/CD integration** with simple exit codes
- **Selective test execution** by pattern matching
- **Performance monitoring** with basic metrics

## Core Features

### Basic Test Execution
```nim
# Run all tests
nim c -r tests/support/simple_runner.nim

# Run specific test suite
nim c -r tests/support/simple_runner.nim --pattern:"Channel"

# Run with verbose output
nim c -r tests/support/simple_runner.nim --verbose
```

### Command Line Options
```bash
Usage: simple_runner [options]

Options:
  --pattern:PATTERN     Run only tests matching pattern
  --verbose             Enable detailed output
  --fail-fast           Stop on first failure
  --timeout:SECONDS     Set test timeout (default: 30)
  --help                Show this help message
```

## Architecture

### Test Discovery
The runner automatically discovers test files using these patterns:
- `test_*.nim` - Standard test files
- `*_test.nim` - Alternative naming convention
- Files in `unit/`, `e2e/`, `performance/` directories

### Execution Model
```nim
# Simple sequential execution
for test in discoveredTests:
  try:
    runTest(test)
    reportSuccess(test)
  except:
    reportFailure(test)
    if failFast:
      break
```

### Result Reporting
- **Exit Code 0**: All tests passed
- **Exit Code 1**: One or more tests failed
- **Exit Code 2**: Test execution error (compilation, etc.)

## Usage Examples

### Development Workflow
```bash
# Quick validation during development
nim c -r tests/support/simple_runner.nim

# Test specific component
nim c -r tests/support/simple_runner.nim --pattern:"channel"

# Debug failing test
nim c -r tests/support/simple_runner.nim --pattern:"failing_test" --verbose

# CI pipeline
nim c -r tests/support/simple_runner.nim --fail-fast
```

### Integration with Build System
```makefile
# Makefile integration
test:
	nim c -r tests/support/simple_runner.nim

test-verbose:
	nim c -r tests/support/simple_runner.nim --verbose

test-unit:
	nim c -r tests/support/simple_runner.nim --pattern:"unit"

test-e2e:
	nim c -r tests/support/simple_runner.nim --pattern:"e2e"
```

### GitHub Actions Integration
```yaml
- name: Run Tests
  run: nim c -r tests/support/simple_runner.nim

- name: Run Unit Tests
  run: nim c -r tests/support/simple_runner.nim --pattern:"unit"

- name: Run with Fail Fast
  run: nim c -r tests/support/simple_runner.nim --fail-fast
```

## Output Format

### Standard Output
```
Running 5 tests...

✓ test_basic_operations (0.023s)
✓ test_channel_send_recv (0.045s)
✓ test_async_operations (0.067s)
✗ test_performance_benchmark (2.134s) - Timeout exceeded
✗ test_memory_usage (0.089s) - Memory limit exceeded

Results: 3 passed, 2 failed
Total time: 2.358s
```

### Verbose Output
```
Running test_basic_operations...
  Setup complete
  Test execution started
  Assertions: 5/5 passed
  Cleanup complete
✓ test_basic_operations (0.023s)

Running test_channel_send_recv...
  Channel created: capacity=10, mode=SPSC
  Send operation: value=42
  Receive operation: value=42
  Channel closed
✓ test_channel_send_recv (0.045s)
```

### Error Details
```
✗ test_performance_benchmark (2.134s)
  Error: Timeout exceeded (expected: 2.0s, actual: 2.134s)
  Location: tests/performance/test_benchmarks.nim:45
  Stack trace:
    ...detailed stack trace...

✗ test_memory_usage (0.089s)
  Error: Memory limit exceeded (limit: 100MB, used: 150MB)
  Location: tests/unit/test_memory.nim:23
```

## Configuration

### Environment Variables
```bash
# Control test behavior
VERBOSE=1 nim c -r tests/support/simple_runner.nim
FAIL_FAST=1 nim c -r tests/support/simple_runner.nim
TEST_TIMEOUT=60 nim c -r tests/support/simple_runner.nim
TEST_PATTERN="channel" nim c -r tests/support/simple_runner.nim
```

### Default Settings
```nim
const
  defaultTimeout* = 30.seconds
  defaultFailFast* = false
  defaultVerbose* = false
  defaultPattern* = ""
```

## Extension Points

### Custom Test Discovery
```nim
proc discoverTests*(pattern: string): seq[string] =
  # Custom discovery logic
  # Return list of test file paths
```

### Custom Reporting
```nim
proc reportTestResult*(test: TestInfo, result: TestResult) =
  # Custom result reporting
  # Called for each test completion
```

### Custom Test Runner
```nim
proc runTestFile*(path: string): TestResult =
  # Custom test execution logic
  # Return test result with metrics
```

## Best Practices

### Development Usage
```bash
# Quick feedback loop
nim c -r tests/support/simple_runner.nim --pattern:"my_feature"

# Debug specific failure
nim c -r tests/support/simple_runner.nim --pattern:"failing_test" --verbose

# Performance monitoring
nim c -r tests/support/simple_runner.nim --pattern:"performance"
```

### CI/CD Integration
```yaml
- name: Test
  run: |
    # Run all tests
    nim c -r tests/support/simple_runner.nim --fail-fast

    # Run performance tests separately
    nim c -r tests/support/simple_runner.nim --pattern:"performance" --timeout:300
```

### Debugging Workflows
```bash
# Isolate failing test
nim c -r tests/support/simple_runner.nim --pattern:"exact_test_name" --verbose

# Check resource usage
nim c -r tests/support/simple_runner.nim --pattern:"memory" --verbose

# Performance profiling
nim c -r tests/support/simple_runner.nim --pattern:"benchmark" --verbose
```

## Limitations

### Compared to Full Test Suite
- No parallel execution
- Limited performance analytics
- Basic error reporting
- No advanced filtering options
- No test categorization

### When to Use Full Runner
```nim
# Use simple runner for:
# - Quick development checks
# - CI/CD pipelines
# - Debugging specific issues
# - Basic validation

# Use full runner (run_tests.nim) for:
# - Comprehensive performance analysis
# - Parallel test execution
# - Advanced reporting and metrics
# - Integration with external tools
```

## Troubleshooting

### Common Issues
```bash
# Compilation errors
nim c tests/support/simple_runner.nim  # Check for syntax errors

# Test discovery fails
ls tests/  # Verify test file locations
nim c -r tests/support/simple_runner.nim --verbose  # See discovery process

# Timeout issues
nim c -r tests/support/simple_runner.nim --timeout:60  # Increase timeout

# Memory issues
nim c -r tests/support/simple_runner.nim --pattern:"memory" --verbose  # Debug memory usage
```

### Debug Output
```bash
# Enable maximum verbosity
VERBOSE=1 nim c -r tests/support/simple_runner.nim --verbose

# Check test file compilation
for test in tests/*_test.nim; do
  echo "Checking $test..."
  nim c --verbosity:0 $test || echo "Failed: $test"
done
```

This simple runner provides essential test execution capabilities for development and CI/CD workflows while maintaining simplicity and reliability.