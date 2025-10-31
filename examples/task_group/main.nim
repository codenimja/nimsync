# examples/task_group/main.nim
# Demonstrate TaskGroup placeholder API (synchronous today)

import nimsync

proc child(id: int) =
  echo "child ", id, " ran"

when isMainModule:
  var g = initTaskGroup()
  g.spawn(proc() = child(1))
  g.spawn(proc() = child(2))
  echo "active count (placeholder): ", g.active
