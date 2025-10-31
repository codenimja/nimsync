## Test core functionality without complex modules

import std/[unittest, strutils]
import nimsync

suite "Core Module Tests":
  test "Basic imports work":
    check true

  test "Main module compiles":
    # Test basic functionality
    let v = version()
    check v.len > 0
    check v.contains(".")
    echo "✅ Version: ", v

echo "✅ Core functionality tests completed"