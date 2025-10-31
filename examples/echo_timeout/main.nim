# examples/echo_timeout/main.nim
# Runnable example: start an async task that echoes a message after a delay,
# and cancel-warn if a timeout elapses before it completes.

import std/asyncdispatch
import std/monotimes
import std/times

proc echoAfter(msg: string; delayMs: int) {.async.} =
  await sleepAsync(delayMs)
  echo msg

proc withTimeout(task: Future[void]; timeoutMs: int): Future[bool] {.async.} =
  ## Wait for `task` until timeout. Returns true if task finished before timeout.
  ## Simple polling loop suitable for an example; not a production select/race.
  let start = getMonoTime()
  let budget = initDuration(milliseconds = timeoutMs.int64)
  while (not task.finished) and (getMonoTime() - start < budget):
    await sleepAsync(10)
  if task.finished:
    await task
    return true
  else:
    return false

when isMainModule:
  let work = echoAfter("echo: done after 500ms", 500)
  let ok = waitFor withTimeout(work, 200) # 200ms timeout will elapse first
  if not ok:
    echo "timed out before echo finished"
