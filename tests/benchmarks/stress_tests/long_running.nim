# long_running.nim
import std/[times, strformat, asyncdispatch, random]

proc simple_task() {.async.} =
  await sleepAsync(rand(10))

proc simple_endurance_test() {.async.} =
  # Simple test to simulate workload
  var tasks = newSeq[Future[void]]()
  for i in 0..<100:
    tasks.add(simple_task())
  await all(tasks)

proc endurance_test() {.async.} =
  echo "⏰ 24-HOUR ENDURANCE TEST STARTED"
  let start = epochTime()
  var cycles = 0

  while epochTime() - start < 24 * 3600:  # For demo, perhaps change to 60 for 1 minute
    await simple_endurance_test()
    inc cycles
    echo &"Cycle {cycles} completed"

  echo &"🏆 SURVIVED {cycles} CYCLES OVER 24 HOURS"

when isMainModule:
  waitFor endurance_test()