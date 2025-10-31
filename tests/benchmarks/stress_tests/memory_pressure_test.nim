# memory_pressure_test.nim
import std/[atomics, random, times, strformat, asyncdispatch]

var total_allocated {.global.}: Atomic[int]

proc memory_pressure_task(chunk_size: int) {.async.} =
  var data = newSeq[int](chunk_size div 4)  # int is 4 bytes
  for i in 0..<data.len:
    data[i] = i * i
  atomicInc(total_allocated, chunk_size)
  let current = total_allocated.load()
  if current mod (10 * 1024 * 1024) == 0:  # Every 10MB
    echo &"📈 Total allocated: {current div (1024*1024)}MB"
  # Simulate some work
  await sleepAsync(10)  # Not in tight loop

proc memory_pressure_test() {.async.} =
  echo "💥 MEMORY PRESSURE TEST: Allocating until OOM"
  const max_tasks = 1000
  const chunk_size = 1024 * 1024  # 1MB per task

  var futures = newSeq[Future[void]]()

  for i in 0..<max_tasks:
    futures.add(memory_pressure_task(chunk_size))
    if i mod 100 == 0:
      await sleepAsync(50)  # Batch and yield to avoid thrashing

  await all(futures)

  let final_total = total_allocated.load()
  echo &"✅ Survived allocation of {final_total div (1024*1024)}MB"

when isMainModule:
  waitFor memory_pressure_test()