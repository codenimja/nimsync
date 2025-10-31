## Simple test runner for nimsync
##
## Runs basic tests without complex async framework

import std/[os, strutils, osproc]

proc runTest(testFile: string): bool =
  echo "🧪 Running: ", testFile
  let cmd = "nim c -r --path:. --hints:off " & testFile
  let result = execCmd(cmd)
  if result == 0:
    echo "✅ PASSED: ", testFile
    return true
  else:
    echo "❌ FAILED: ", testFile
    return false

proc main() =
  echo "🚀 nimsync Test Suite"
  echo "==================="

  var passed = 0
  var total = 0

  let basicTests = [
    "tests/test_basic.nim",
    "tests/test_core.nim",
    "tests/test_comprehensive.nim",
    "tests/test_simple_coverage.nim"
  ]

  for test in basicTests:
    if fileExists(test):
      inc total
      if runTest(test):
        inc passed
    else:
      echo "⚠️  Test file not found: ", test

  echo ""
  echo "📊 Results: ", passed, "/", total, " tests passed"

  if passed == total:
    echo "🎉 All tests passed!"
  else:
    echo "❌ Some tests failed"
    quit(1)

when isMainModule:
  main()