## Minimal taskGroup test

import chronos
import nimsync

proc testTaskGroup() {.async.} =
  echo "Testing taskGroup template"
  
  # Try simplest possible case
  var group = initTaskGroup()
  echo "TaskGroup initialized"
  
  # This should work with the low-level API
  proc simpleTask(): Future[void] {.async.} =
    echo "Simple task running"
  
  discard group.spawn(simpleTask)
  echo "Task spawned"
  
  await group.join()
  echo "Task joined"

when isMainModule:
  waitFor testTaskGroup()