## Select Operations Example
##
## Demonstrates practical usage of select operations for:
## - Multi-channel coordination
## - Timeout handling
## - Load balancing between channels
## - Producer-consumer patterns with fairness

import std/[strformat, random, times]
import chronos
import nimsync

type
  WorkRequest = object
    id: int
    data: string
    priority: int

  WorkResult = object
    requestId: int
    result: string
    processingTime: float

proc worker(id: int, requests: var Channel[WorkRequest],
           results: var Channel[WorkResult]) {.async.} =
  ## Worker that processes requests from a channel
  echo fmt"🔧 Worker {id} started"

  while true:
    try:
      # Wait for work with timeout
      var selectBuilder = initSelect[WorkRequest]()
        .recv(requests)
        .timeout(5000)  # 5 second timeout

      let selectResult = await selectBuilder.run()

      if selectResult.isTimeout:
        echo fmt"⏰ Worker {id}: No work for 5 seconds, taking a break..."
        await sleepAsync(1.seconds)
        continue

      let request = selectResult.value
      echo fmt"📋 Worker {id}: Processing request {request.id}"

      # Simulate work (random processing time)
      let startTime = cpuTime()
      await sleepAsync(chronos.milliseconds(rand(100..500)))
      let processingTime = cpuTime() - startTime

      # Send result
      let result = WorkResult(
        requestId: request.id,
        result: fmt"Processed: {request.data}",
        processingTime: processingTime
      )

      await results.send(result)
      echo fmt"✅ Worker {id}: Completed request {request.id}"

    except CatchableError as e:
      echo fmt"❌ Worker {id}: Error: {e.msg}"
      break

  echo fmt"🛑 Worker {id} stopped"

proc loadBalancer(inputChannels: var openArray[Channel[WorkRequest]],
                 outputChannel: var Channel[WorkRequest]) {.async.} =
  ## Load balancer that fairly distributes work from multiple input channels
  echo "⚖️  Load balancer started"

  var fairnessIndex = 0

  while true:
    # Create cases for all input channels
    var cases: seq[SelectCase[WorkRequest]] = @[]
    for i, ch in inputChannels:
      if not ch.isClosed():
        cases.add(SelectCase[WorkRequest](
          channel: addr inputChannels[i],
          isRecv: true
        ))

    if cases.len == 0:
      echo "📭 Load balancer: All input channels closed"
      break

    # Use fair selection to prevent starvation
    let result = fairSelect(cases, fairnessIndex)

    if result.caseIndex >= 0:
      let request = result.value
      echo fmt"📤 Load balancer: Routing request {request.id} (priority: {request.priority})"
      await outputChannel.send(request)
    else:
      # No immediate work, yield
      await sleepAsync(10.milliseconds)

  echo "🛑 Load balancer stopped"

proc prioritySelector(normalCh, priorityCh: var Channel[WorkRequest],
                     outputCh: var Channel[WorkRequest]) {.async.} =
  ## Selector that prioritizes high-priority requests
  echo "🎯 Priority selector started"

  while true:
    # Always check priority channel first, then normal channel
    var selectBuilder = initSelect[WorkRequest]()
      .recv(priorityCh)    # Priority channel checked first
      .recv(normalCh)      # Normal channel checked second
      .timeout(1000)

    let result = await selectBuilder.run()

    if result.isTimeout:
      echo "⏰ Priority selector: No work available"
      continue

    let request = result.value
    let channelType = if result.caseIndex == 0: "PRIORITY" else: "NORMAL"

    echo fmt"📋 Priority selector: {channelType} request {request.id}"
    await outputCh.send(request)

proc monitoringExample() {.async.} =
  ## Example of using select for monitoring multiple channels
  echo "\n🔍 === Monitoring Example ==="

  var statusCh = newChannel[string](10)
  var errorCh = newChannel[string](10)
  var metricsCh = newChannel[string](10)

  # Simulate different types of events
  await statusCh.send("System started")
  await errorCh.send("Connection timeout")
  await metricsCh.send("CPU: 45%")
  await statusCh.send("Task completed")

  # Monitor all channels with select
  for i in 1..4:
    var selectBuilder = initSelect[string]()
      .recv(statusCh)
      .recv(errorCh)
      .recv(metricsCh)
      .timeout(500)

    let result = await selectBuilder.run()

    if result.isTimeout:
      echo "⏰ Monitor: No events"
    else:
      let eventType = case result.caseIndex:
        of 0: "STATUS"
        of 1: "ERROR"
        of 2: "METRICS"
        else: "UNKNOWN"

      echo fmt"📊 Monitor: {eventType} - {result.value}"

proc main() {.async.} =
  echo "🚀 nimsync Select Operations Example"
  echo "====================================="

  randomize()

  # Example 1: Basic select with timeout
  echo "\n⚡ === Basic Select Example ==="

  var fastCh = newChannel[int](5)
  var slowCh = newChannel[int](5)

  # Send to fast channel immediately
  await fastCh.send(42)

  # Try to receive from either channel
  var selectBuilder = initSelect[int]()
    .recv(fastCh)
    .recv(slowCh)
    .timeout(1000)

  let result = await selectBuilder.run()

  if result.isTimeout:
    echo "⏰ Timed out waiting for data"
  else:
    let source = if result.caseIndex == 0: "fast" else: "slow"
    echo fmt"📨 Received {result.value} from {source} channel"

  # Example 2: Worker pool with load balancing
  echo "\n👷 === Worker Pool Example ==="

  var requestQueue = newChannel[WorkRequest](20)
  var resultQueue = newChannel[WorkResult](20)

  # Simulate worker pool by processing requests one by one
  # Generate work requests
  for i in 1..3:
    let request = WorkRequest(
      id: i,
      data: fmt"Task-{i}",
      priority: rand(1..3)
    )
    await requestQueue.send(request)

  # Process requests
  for i in 1..3:
    await worker(1, requestQueue, resultQueue)

  # Collect results
  echo "📋 Collecting results..."
  for i in 1..3:
    var selectBuilder = initSelect[WorkResult]()
      .recv(resultQueue)
      .timeout(2000)

    let result = await selectBuilder.run()
    if not result.isTimeout:
      echo fmt"📋 Result: {result.value.result} (took {result.value.processingTime:.3f}s)"

  # Example 3: Priority-based selection
  echo "\n🎯 === Priority Selection Example ==="

  var normalQueue = newChannel[WorkRequest](10)
  var priorityQueue = newChannel[WorkRequest](10)
  var outputQueue = newChannel[WorkRequest](10)

  # Note: In a real application, you'd run prioritySelector concurrently
  # For this example, we'll simulate its behavior

  # Send mixed priority requests
  await normalQueue.send(WorkRequest(id: 1, data: "Normal task", priority: 1))
  await priorityQueue.send(WorkRequest(id: 2, data: "Priority task", priority: 3))
  await normalQueue.send(WorkRequest(id: 3, data: "Another normal", priority: 1))

  # Close input channels
  normalQueue.close()
  priorityQueue.close()

  # See the order they come out (priority should come first)
  try:
    while true:
      var selectBuilder = initSelect[WorkRequest]()
        .recv(outputQueue)
        .timeout(100)

      let result = await selectBuilder.run()
      if result.isTimeout:
        break

      echo fmt"📤 Output: {result.value.data} (priority: {result.value.priority})"
  except:
    discard

  # Example 4: Monitoring multiple event channels
  await monitoringExample()

  echo "\n🎉 Select operations example completed!"

when isMainModule:
  waitFor main()