# nimsync.nimble
version       = "1.1.0"
author        = "boonzy"
description   = "Production-ready async runtime with lock-free SPSC channels (615M ops/sec, 31ns P99)"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.0.0"
requires "chronos >= 4.0.0"

# This is a library package, no binary to build

task test, "Run all tests":
  exec "./scripts/test.sh full"

task bench, "Run performance benchmarks":
  exec "./tests/performance/run_all_benchmarks.sh"

task fmt, "Format source code":
  exec "nimpretty --backup:off src"
  exec "nimpretty --backup:off tests"
  exec "nimpretty --backup:off examples"

task lint, "Run static analysis and checks":
  exec "nim check --hints:off src/nimsync.nim"
  exec "nim check --hints:off tests/unit/test_basic.nim"
  exec "nim check --hints:off tests/unit/test_simple_core.nim"
  exec "nim check --hints:off examples/hello/main.nim"

task clean, "Clean build artifacts":
  exec "rm -rf src/htmldocs/"
  exec "rm -f nimsync"
  exec "rm -f build/cli"
  exec "find . -name '*.exe' -delete"
  exec "find . -name '*.dll' -delete"
  exec "find . -name '*.so' -delete"
  exec "find . -name '*.dylib' -delete"

task build, "Build the library (no-op for library package)":
  echo "nimsync is a library package. Use 'nimble install' to install it or build examples directly."

task buildRelease, "Build optimized release (no-op for library package)":
  echo "nimsync is a library package. Use 'nimble install' to install it or build examples directly."

task ci, "Run CI checks":
  exec "nimble test"
  exec "nimble lint"
