## Simple test to verify select operations work

import std/strformat
import chronos
import ../../src/nimsync

proc testBasicSelect() {.async.} =
  echo "🧪 Testing basic select operations..."

  var ch1 = newChannel[int](10, ChannelMode.SPSC)
  var ch2 = newChannel[int](10, ChannelMode.SPSC)

  # Send to first channel (non-blocking)
  if not ch1.spsc.trySend(42):
    echo "❌ Failed to send to channel"
    return

  echo "📤 Sent 42 to ch1"

  # Create select operation
  var selectBuilder = initSelect[int]()
  selectBuilder = selectBuilder
    .recv(ch1)
    .recv(ch2)
    .timeout(1000)

  echo "⚡ Running select operation..."
  let result = await selectBuilder.run()

  echo fmt"📊 Select result: timeout={result.isTimeout}, caseIndex={result.caseIndex}, value={result.value}"

  if not result.isTimeout and result.caseIndex == 0 and result.value == 42:
    echo "✅ Test PASSED!"
  else:
    echo "❌ Test FAILED!"

proc main() {.async.} =
  await testBasicSelect()

when isMainModule:
  waitFor main()