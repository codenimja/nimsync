#!/bin/bash
set -e

# Test script for local development
# Usage: ./scripts/test.sh [fast|full|coverage|performance]

MODE=${1:-fast}

echo "🧪 Running nimsync tests in $MODE mode..."

case $MODE in
  "fast")
    echo "⚡ Fast test mode"
    nim c -r tests/support/simple_runner.nim
    ;;

  "full")
    echo "🔍 Full test mode"

    # Basic tests
    echo "Running basic tests..."
    nim c -r tests/unit/test_basic.nim
    nim c -r tests/unit/test_simple_core.nim
    nim c -r tests/integration/test_comprehensive.nim
    nim c -r tests/unit/test_simple_coverage.nim
    nim c -r tests/support/simple_runner.nim

    # Optimized build tests
    echo "Testing optimized build..."
    nim c -d:release --opt:speed tests/support/simple_runner.nim
    ./tests/support/simple_runner

    # Statistics enabled tests
    echo "Testing with statistics..."
    nim c -d:statistics tests/support/simple_runner.nim
    ./tests/support/simple_runner

    echo "✅ All tests passed!"
    ;;

  "coverage")
    echo "📊 Coverage test mode"

    # Compile with line tracing
    nim c --lineTrace:on --stackTrace:on tests/support/simple_runner.nim
    nim c --lineTrace:on --stackTrace:on tests/unit/test_basic.nim
    nim c --lineTrace:on --stackTrace:on tests/integration/test_core.nim
    nim c --lineTrace:on --stackTrace:on tests/integration/test_comprehensive.nim
    nim c --lineTrace:on --stackTrace:on tests/unit/test_simple_coverage.nim

    # Run all tests
    ./tests/support/simple_runner
    ./tests/unit/test_basic
    ./tests/integration/test_core
    ./tests/integration/test_comprehensive
    ./tests/unit/test_simple_coverage

    echo "📈 Coverage testing completed"
    ;;

  "performance")
    echo "🚀 Performance test mode"

    # Build optimized version
    nim c -d:release --opt:speed --hints:off tests/support/simple_runner.nim

    # Run performance benchmarks
    echo "Running performance benchmarks..."

    if command -v hyperfine &> /dev/null; then
      hyperfine --warmup 3 --runs 10 "./tests/support/simple_runner"
    else
      echo "Install hyperfine for detailed benchmarks"
      time ./tests/support/simple_runner
    fi

    # Memory usage
    echo "Memory usage:"
    /usr/bin/time -v ./tests/support/simple_runner 2>&1 | grep -E "(Maximum resident set size|Page reclaims)"

    # Binary size
    echo "Binary sizes:"
    ls -lh tests/simple_runner | awk '{print $5 " " $9}'

    echo "⚡ Performance testing completed"
    ;;

  *)
    echo "❌ Unknown mode: $MODE"
    echo "Usage: $0 [fast|full|coverage|performance]"
    exit 1
    ;;
esac

echo "🎉 Test suite completed successfully!"