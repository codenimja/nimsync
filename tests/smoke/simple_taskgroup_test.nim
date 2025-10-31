## Simple taskGroup example

import chronos
import nimsync

proc task1(): Future[void] {.async.} =
  echo "Task 1 running"
  await sleepAsync(100.milliseconds)
  echo "Task 1 completed"

proc task2(): Future[void] {.async.} =
  echo "Task 2 running"
  await sleepAsync(50.milliseconds)
  echo "Task 2 completed"

proc testTaskGroup() {.async.} =
  echo "=== Simple TaskGroup Example ==="
  
  # Following the exact pattern from the template documentation
  taskGroup:
    discard g.spawn(task1)
    discard g.spawn(task2)
  
  echo "All tasks completed!"

when isMainModule:
  waitFor testTaskGroup()