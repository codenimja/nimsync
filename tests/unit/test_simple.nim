## Simple compilation test to verify basic functionality

import std/unittest
import ../../src/nimsync

suite "Simple Compilation Tests":
  test "Basic imports work":
    check true

  test "Version function exists":
    let v = version()
    check v.len > 0
    echo "nimsync version: ", v

echo "✅ Basic compilation test passed"