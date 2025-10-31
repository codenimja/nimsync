## Simple Test Runner for nimsync
##
## Lightweight test runner optimized for CI and development

import std/[os, strutils, times]
import support/test_fixtures
import support/async_test_framework

# Import basic tests
import unit/test_basic
import unit/test_simple
import unit/test_simple_core

proc main() =
  echo "=== nimsync Simple Test Runner ==="
  echo fmt"Started at: {now()}"
  echo ""

  # Configure test environment
  configureTestsForEnvironment()
  setupTestEnvironment()

  echo "Running basic tests..."

  let startTime = getMonoTime()

  try:
    # The unittest framework will automatically run all imported tests
    echo "✓ All basic tests completed"
  except CatchableError as e:
    echo fmt"✗ Test execution failed: {e.msg}"
    quit(1)

  finally:
    let endTime = getMonoTime()
    let duration = endTime - startTime
    teardownTestEnvironment()

    echo ""
    echo fmt"Total Execution Time: {duration.inMilliseconds}ms"
    
    let stats = getTestStats()
    echo fmt"Tests Run: {stats.run}, Passed: {stats.passed}, Failed: {stats.failed}"

    if stats.failed > 0:
      echo "❌ Some tests failed"
      quit(1)
    else:
      echo "✅ All tests passed!"

when isMainModule:
  main()