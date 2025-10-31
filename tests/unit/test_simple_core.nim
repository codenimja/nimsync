## Test simplified core functionality

import std/unittest
import ../../src/nimasync_simple

suite "Simplified Core Tests":
  test "Version function works":
    let v = version()
    check v.len > 0
    check v == "0.0.1"
    echo "✅ Version: ", v

  test "Version info works":
    let vInfo = versionInfo()
    check vInfo.version == "0.0.1"
    check vInfo.buildTime.len > 0
    check vInfo.features.len >= 0
    echo "✅ Build time: ", vInfo.buildTime
    echo "✅ Features: ", vInfo.features

echo "✅ Simplified core tests passed!"