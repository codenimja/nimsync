## Basic functionality test

import std/[unittest, strutils]
import nimsync

suite "Basic nimsync Tests":
  test "Version function works":
    let v = version()
    check v.len > 0
    echo "✅ nimsync version: ", v

  test "Basic version format":
    let v = version()
    check v.contains(".")

echo "✅ All basic tests passed!"