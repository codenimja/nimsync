# examples/hello/main.nim
# Minimal runnable example using Nim stdlib async primitives

import std/asyncdispatch

proc hello() {.async.} =
  await sleepAsync(200) # milliseconds
  echo "Hello from nimsync example (200ms delay)"

proc main() {.async.} =
  await hello()

waitFor main()
