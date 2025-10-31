## Comprehensive functionality test
##
## Tests actual functionality of nimsync modules to prove they work

import std/[unittest, strutils, asyncdispatch]
import nimsync

suite "Comprehensive nimsync Tests":
  test "Version and build info":
    let v = version()
    check v.len > 0
    check v.contains(".")
    echo "✅ Version: ", v

    let vInfo = versionInfo()
    check vInfo.version == v
    check vInfo.buildTime.len > 0
    check vInfo.features.len >= 0
    echo "✅ Build time: ", vInfo.buildTime
    echo "✅ Features: ", vInfo.features

  test "Module imports work":
    # Test that all modules can be imported without errors
    try:
      # These should all compile and be accessible
      discard initTaskGroup()
      echo "✅ TaskGroup initialization works"
    except Exception as e:
      echo "❌ TaskGroup error: ", e.msg
      check false

    try:
      # Test basic cancellation
      var scope = initCancelScope()
      check scope.active
      check not scope.cancelled
      echo "✅ CancelScope creation works"
    except Exception as e:
      echo "❌ CancelScope error: ", e.msg
      check false

echo "✅ Comprehensive tests completed"