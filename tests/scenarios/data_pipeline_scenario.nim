## Data Pipeline Scenario Test
## Demonstrates nimsync streams for processing data pipelines with backpressure
## Mock data simulates log processing and analytics

import nimsync
import std/[strutils, sequtils, random]

type
  LogEntry = object
    timestamp: string
    level: string
    message: string
    userId: int

proc generateMockLogs(count: int): seq[LogEntry] =
  ## Generate mock log data
  for i in 1..count:
    result.add LogEntry(
      timestamp: "2025-10-28T" & $rand(10..23) & ":" & $rand(0..59).intToStr(2) & ":00Z",
      level: sample(["INFO", "WARN", "ERROR", "DEBUG"]),
      message: "Mock log message " & $i,
      userId: rand(1..1000)
    )

proc filterErrors(entry: LogEntry): bool =
  entry.level == "ERROR"

proc enrichWithUserData(entry: LogEntry): Future[LogEntry] {.async.} =
  # Simulate enriching with user data
  await sleepAsync(5.milliseconds)
  result = entry
  result.message &= " [User: " & $entry.userId & "]"

proc aggregateByLevel(entries: seq[LogEntry]): Table[string, int] =
  for entry in entries:
    result.mgetOrPut(entry.level, 0) += 1

proc dataPipelineScenario*() {.async.} =
  ## Main test scenario: Process log data through a pipeline
  echo "Starting data pipeline scenario..."

  # Generate mock data
  let mockLogs = generateMockLogs(100)

  # Create a stream with backpressure
  var logStream = initStream[LogEntry](Block)

  # Producer: Send logs to stream
  proc producer() {.async.} =
    for log in mockLogs:
      await logStream.send(log)
      await sleepAsync(1.milliseconds)  # Simulate input rate
    logStream.close()

  # Consumer pipeline
  proc consumer() {.async.} =
    var processedLogs: seq[LogEntry]

    # Stage 1: Filter errors
    let errorStream = logStream.filter(filterErrors)

    # Stage 2: Enrich with user data (concurrent processing)
    await taskGroup:
      for entry in errorStream:
        proc enrich(entry: LogEntry) {.async.} =
          let enriched = await enrichWithUserData(entry)
          processedLogs.add enriched
        discard g.spawn enrich(entry)

    # Stage 3: Aggregate results
    let stats = aggregateByLevel(processedLogs)

    echo "Pipeline processing completed:"
    for level, count in stats:
      echo &"  {level}: {count} entries"

    echo &"Total processed: {processedLogs.len}"

  # Run producer and consumer concurrently
  await taskGroup:
    discard g.spawn producer()
    discard g.spawn consumer()

  echo "Data pipeline scenario completed."

when isMainModule:
  waitFor dataPipelineScenario()