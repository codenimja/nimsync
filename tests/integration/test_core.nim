## Test core functionality without complex modules

import std/[unittest, strutils]
import nimsync

suite "Core Module Tests":
  test "Basic imports work":
    check true

  test "Main module compiles":
    try:
      # Test basic functionality
      let v = version()
      check v.len > 0
      check v.contains(".")
      echo "✅ Version: ", v

      # Test version info
      let vInfo = versionInfo()
      check vInfo.version == v
      check vInfo.buildTime.len > 0
      echo "✅ Build time: ", vInfo.buildTime
      echo "✅ Features: ", vInfo.features

    except Exception as e:
      echo "❌ Error: ", e.msg
      check false

echo "✅ Core functionality tests completed"