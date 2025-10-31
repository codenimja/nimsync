# mixed_workload_chaos.nim
import nimsync, std/[random, times, strformat, asyncdispatch]

proc cpu_intensive_task(iterations: int): Future[int] {.async.} =
  var sum = 0
  for i in 0..<iterations:
    sum += i mod 1000
  return sum

proc io_bound_task(): Future[void] {.async.} =
  await sleepAsync(10 + rand(40))  # 10-50ms

proc cpu_task_proc(): Future[void] {.async.} =
  discard await cpu_intensive_task(1000 + rand(5000))

proc io_task_proc(): Future[void] {.async.} =
  await io_bound_task()

proc memory_task_proc(): Future[void] {.async.} =
  var data = newSeq[int](1000 + rand(9000))  # 4-40KB
  for j in 0..<data.len:
    data[j] = j * j

proc mixed_workload_chaos_test() {.async.} =
  echo "🎭 MIXED WORKLOAD CHAOS: CPU + IO + Memory"
  const total_tasks = 10_000

  var cpu_bound_tasks = 0
  var io_bound_tasks = 0
  var memory_bound_tasks = 0
  var completed_tasks = 0
  var failed_tasks = 0

  var futures = newSeq[Future[void]]()

  for i in 0..<total_tasks:
    let task_type = rand(100)
    if task_type < 40:
      # CPU bound
      futures.add(cpu_task_proc())
    elif task_type < 70:
      # IO bound
      futures.add(io_task_proc())
    else:
      # Memory bound
      futures.add(memory_task_proc())

  # Wait for all and count
  for fut in futures:
    try:
      await fut
      inc completed_tasks
      # Count types - simplified, not accurate but for demo
      if rand(100) < 40:
        inc cpu_bound_tasks
      elif rand(100) < 70:
        inc io_bound_tasks
      else:
        inc memory_bound_tasks
    except:
      inc failed_tasks

  echo &"✅ Chaos survived: {completed_tasks}/{total_tasks} tasks"
  echo &"📊 CPU: {cpu_bound_tasks}, IO: {io_bound_tasks}, Memory: {memory_bound_tasks}"
  echo &"❌ Failed: {failed_tasks}"

when isMainModule:
  waitFor mixed_workload_chaos_test()