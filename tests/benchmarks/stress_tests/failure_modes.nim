# failure_modes.nim
import nimsync, std/[times, strformat, asyncdispatch]

proc killer_proc(ch: Channel[int]) {.async.} =
  for i in 1..100:
    while not ch.trySend(i):
      await sleepAsync(1)
    if i == 50:
      raise newException(Defect, "CRITICAL FAILURE")

proc worker_proc(ch: Channel[int]) {.async.} =
  try:
    while true:
      var x: int
      while not ch.tryReceive(x):
        await sleepAsync(1)
      echo &"Processed {x}"
  except CatchableError:
    echo "Worker caught error - continuing..."
  except Defect:
    echo "💥 UNRECOVERABLE - worker dead"

proc cascading_failure_test() {.async.} =
  echo "💀 CASCADING FAILURE SIMULATION"
  let ch = newChannel[int](10, ChannelMode.SPSC)

  let killer = killer_proc(ch)
  let worker = worker_proc(ch)

  try:
    await all(killer, worker)
  except Defect:
    echo "System survived uncaught Defect"

when isMainModule:
  waitFor cascading_failure_test()