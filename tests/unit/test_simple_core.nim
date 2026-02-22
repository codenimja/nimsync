## Test core version functionality

import std/unittest
import ../../src/nimsync

suite "Core Version Tests":
  test "Version function works":
    let v = version()
    check v.len > 0
    check v == "1.1.0"
    echo "Version: ", v

  test "Version starts with expected major":
    let v = version()
    check v.startsWith("1.")

echo "Core version tests passed!"
