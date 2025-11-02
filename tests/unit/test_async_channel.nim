## Test async send/recv after fix

import nimsync except send, recv
import nimsync/channels as ch_ops
import chronos

proc testAsyncSendRecv() {.async.} =
  let ch = newChannel[int](4, ChannelMode.SPSC)

  # Test basic async send/recv
  await ch_ops.send(ch, 42)
  let val = await ch_ops.recv(ch)
  doAssert val == 42, "Expected 42, got " & $val

  echo "✅ Basic async send/recv works"

  # Test backpressure (fill channel)
  await ch_ops.send(ch, 1)
  await ch_ops.send(ch, 2)
  await ch_ops.send(ch, 3)
  await ch_ops.send(ch, 4)

  echo "✅ Channel filled (4 items)"

  # Consume and verify
  doAssert (await ch_ops.recv(ch)) == 1
  doAssert (await ch_ops.recv(ch)) == 2
  doAssert (await ch_ops.recv(ch)) == 3
  doAssert (await ch_ops.recv(ch)) == 4

  echo "✅ All values received correctly"

proc testConcurrentAsyncOps() {.async.} =
  let ch = newChannel[int](8, ChannelMode.SPSC)

  proc producer() {.async.} =
    for i in 1..10:
      await ch_ops.send(ch, i)

  proc consumer() {.async.} =
    for i in 1..10:
      let val = await ch_ops.recv(ch)
      doAssert val == i, "Expected " & $i & ", got " & $val

  await allFutures([producer(), consumer()])
  echo "✅ Concurrent async producer/consumer works"

waitFor testAsyncSendRecv()
waitFor testConcurrentAsyncOps()

echo "✅ All async channel tests passed!"
