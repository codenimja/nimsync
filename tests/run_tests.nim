## Comprehensive Test Runner for nimsync
##
## Runs all tests with proper organization and reporting

import std/[os, strutils, times]
import support/test_fixtures

# Import all test modules
import unit/test_basic
import unit/test_simple
import unit/test_simple_core
import unit/test_simple_coverage
import unit/test_simple_select
import unit/channels/test_spsc_channel
import unit/channels/test_mpmc_channel
import unit/groups/test_task_group
import unit/cancel/test_cancellation
import integration/test_channels
import integration/test_taskgroup
import integration/test_cancelscope
import integration/test_comprehensive
import integration/test_core
import integration/test_errors
import integration/test_select
import e2e/test_complete_workflows
import performance/test_benchmarks

proc main() =
  echo "=== nimsync Comprehensive Test Suite ==="
  echo fmt"Started at: {now()}"
  echo ""

  # Configure test environment
  configureTestsForEnvironment()
  setupTestEnvironment()

  echo "Test Configuration:"
  echo fmt"  Timeout: {testConfig.timeout}"
  echo fmt"  Max Memory: {testConfig.maxMemory} bytes"
  echo fmt"  Verbose: {testConfig.verbose}"
  echo fmt"  Expected Throughput: {testConfig.expectedThroughput}"
  echo ""

  let startTime = getMonoTime()

  try:
    # Run all unit tests
    echo "Running Unit Tests..."
    echo "==================="

    # The unittest framework will automatically run all imported tests
    echo "✓ All test suites completed"

  except CatchableError as e:
    echo fmt"✗ Test execution failed: {e.msg}"
    quit(1)

  finally:
    let endTime = getMonoTime()
    let duration = endTime - startTime

    teardownTestEnvironment()

    echo ""
    echo "=== Test Execution Summary ==="
    let stats = getTestStats()
    echo fmt"Total Tests: {stats.run}"
    echo fmt"Passed: {stats.passed}"
    echo fmt"Failed: {stats.failed}"
    echo fmt"Success Rate: {(stats.passed.float / stats.run.float * 100.0):.1f}%"
    echo fmt"Average Duration: {stats.avgDuration:.2f}ms per test"
    echo fmt"Total Execution Time: {duration.inMilliseconds}ms"

    if stats.failed > 0:
      echo ""
      echo "❌ Some tests failed. Check output above for details."
      quit(1)
    else:
      echo ""
      echo "✅ All tests passed successfully!"

when isMainModule:
  main()