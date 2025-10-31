# nimsync.nimble
version       = "0.1.0"
author        = "codenimja"
description   = "213M+ ops/sec lock-free SPSC channels in Nim"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.0.0"

task test, "Run all tests":
  exec "nim c -r --threads:on --mm:orc tests/unit/test_channel.nim"

task bench, "Run performance benchmark":
  exec "nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim && ./tests/performance/benchmark_spsc"

task fmt, "Format source code":
  exec "nimpretty --backup:off src"
  exec "nimpretty --backup:off tests"
  exec "nimpretty --backup:off examples"

task lint, "Run static analysis and checks":
  exec "nim check --hints:off src/nimsync.nim"
  exec "nim check --hints:off tests/test_basic.nim"
  exec "nim check --hints:off tests/test_core.nim"
  exec "nim check --hints:off examples/hello/main.nim"

task clean, "Clean build artifacts":
  exec "rm -rf src/htmldocs/"
  exec "rm -f nimsync"
  exec "rm -f build/cli"
  exec "find . -name '*.exe' -delete"
  exec "find . -name '*.dll' -delete"
  exec "find . -name '*.so' -delete"
  exec "find . -name '*.dylib' -delete"

task build, "Build the library":
  exec "nim c --noMain --app:lib src/nimsync.nim"

task buildRelease, "Build optimized release":
  exec "nim c -d:release --opt:speed --noMain --app:lib src/nimsync.nim"

task ci, "Run CI checks":
  exec "nimble test"
  exec "nimble lint"
  exec "nimble docs"
