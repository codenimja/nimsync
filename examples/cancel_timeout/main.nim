# examples/cancel_timeout/main.nim
# Demonstrate cancellation placeholder API pattern

import nimsync

proc doWork(scope: var CancelScope) =
  # Placeholder work; would check scope.cancelled in a real async loop
  echo "doing work (placeholder)"
  # Simulate a condition to cancel
  cancel(scope)
  echo "cancel requested: ", scope.cancelled

when isMainModule:
  withCancelScope(proc(scope: var CancelScope) =
    doWork(scope)
  )
