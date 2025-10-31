## Performance benchmark for select operations

import std/strformat
import chronos
import nimsync

proc benchBasicSelect() {.async.} =
  ## Benchmark basic select operation performance
  echo "🏃 Benchmarking basic select operations..."

  const NumOperations = 1000
  var ch1 = newChannel[int](NumOperations, ChannelMode.SPSC)
  var ch2 = newChannel[int](NumOperations, ChannelMode.SPSC)

  # Fill first channel with data
  for i in 1..NumOperations:
    discard ch1.spsc.trySend(i)

  let startTime = Moment.now()

  # Perform many select operations
  for i in 1..NumOperations:
    var selectBuilder = initSelect[int]()
    selectBuilder = selectBuilder.recv(ch1).recv(ch2).timeout(1000)

    let result = await selectBuilder.run()
    if result.isTimeout or result.value != i:
      echo fmt"❌ Unexpected result at iteration {i}"
      return

  let elapsed = Moment.now() - startTime
  let elapsedNs = elapsed.inNanoseconds
  let elapsedMs = elapsedNs.float / 1_000_000.0
  let avgTime = elapsedMs * 1000 / NumOperations.float
  let throughput = float(NumOperations) / (elapsedMs / 1000.0)

  echo fmt"✅ {NumOperations} select operations completed"
  echo fmt"⏱️  Total time: {elapsedMs}ms"
  echo fmt"🏃 Average: {avgTime:.1f} microseconds per operation"
  echo fmt"📊 Throughput: {throughput:.0f} operations/second"

proc benchSelectTimeout() {.async.} =
  ## Benchmark select timeout performance
  echo "⏰ Benchmarking select timeout operations..."

  const NumOperations = 100
  var ch1 = newChannel[int](1, ChannelMode.SPSC)
  var ch2 = newChannel[int](1, ChannelMode.SPSC)

  let startTime = Moment.now()

  # Perform select operations that will timeout
  for i in 1..NumOperations:
    var selectBuilder = initSelect[int]()
    selectBuilder = selectBuilder.recv(ch1).recv(ch2).timeout(1)  # Very short timeout

    let result = await selectBuilder.run()
    if not result.isTimeout:
      echo fmt"❌ Expected timeout at iteration {i}"
      return

  let elapsed = Moment.now() - startTime
  let elapsedNs = elapsed.inNanoseconds
  let elapsedMs = elapsedNs.float / 1_000_000.0
  let avgTime = elapsedMs * 1000 / NumOperations.float

  echo fmt"✅ {NumOperations} timeout operations completed"
  echo fmt"⏱️  Total time: {elapsedMs}ms"
  echo fmt"🏃 Average: {avgTime:.1f} microseconds per timeout"

proc benchImmediateSelect() =
  ## Benchmark immediate (non-blocking) select operations
  echo "⚡ Benchmarking immediate select operations..."

  const NumOperations = 10000
  var ch1 = newChannel[int](NumOperations, ChannelMode.SPSC)
  var ch2 = newChannel[int](NumOperations, ChannelMode.SPSC)

  # Fill both channels with data
  for i in 1..NumOperations:
    discard ch1.spsc.trySend(i)
    discard ch2.spsc.trySend(i + NumOperations)

  var received = 0
  let startTime = Moment.now()

  # Perform immediate select operations
  while received < NumOperations * 2:
    var cases = [
      SelectCase[int](channel: addr ch1, isRecv: true),
      SelectCase[int](channel: addr ch2, isRecv: true)
    ]

    let result = selectImmediate(cases)
    if result.caseIndex >= 0:
      inc received
    else:
      break  # No more data

  let elapsed = Moment.now() - startTime
  let elapsedNs = elapsed.inNanoseconds
  let elapsedMs = elapsedNs.float / 1_000_000.0
  let avgTime = elapsedMs * 1000000.0 / received.float
  let throughput = float(received) / (elapsedMs / 1000.0)

  echo fmt"✅ {received} immediate operations completed"
  echo fmt"⏱️  Total time: {elapsedMs}ms"
  echo fmt"🏃 Average: {avgTime:.0f} nanoseconds per operation"
  echo fmt"📊 Throughput: {throughput:.0f} operations/second"

proc main() {.async.} =
  echo "🧪 nimsync Select Operations Performance Benchmark"
  echo "================================================="

  await benchBasicSelect()
  echo ""

  await benchSelectTimeout()
  echo ""

  benchImmediateSelect()
  echo ""

  echo "🎉 Performance benchmarks completed!"

when isMainModule:
  waitFor main()