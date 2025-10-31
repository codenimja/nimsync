import nimsync

proc simpleTask(): Future[void] {.async.} =
  echo "Task running"
  await sleepAsync(100.milliseconds)
  echo "Task completed"

proc testTemplate() {.async.} =
  echo "Testing taskGroup template"
  
  # Try the template without await first
  taskGroup:
    discard g.spawn(simpleTask)
    discard g.spawn(simpleTask)
  
  echo "Template test completed"

when isMainModule:
  waitFor testTemplate()