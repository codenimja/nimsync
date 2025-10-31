## Streams with Backpressure Example
##
## Demonstrates stream processing with backpressure control, showing
## how nimsync will handle data flow control in async pipelines.
##
## This example shows the planned API for Stream/Sink types with
## combinators and backpressure-aware operations.

import std/[times, strformat, sequtils]
import chronos
import nimsync/[channels, group, cancel]

type
  # Placeholder types for the planned Stream/Sink API
  StreamItem = object
    id: int
    data: string
    size: int

  # In the real implementation, these would be proper Stream[T]/Sink[T] types
  MockStream = object
    items: seq[StreamItem]
    position: int
    capacity: int

  MockSink = object
    buffer: seq[StreamItem]
    capacity: int

proc newMockStream(items: seq[StreamItem], capacity: int = 10): MockStream =
  MockStream(items: items, position: 0, capacity: capacity)

proc newMockSink(capacity: int = 10): MockSink =
  MockSink(buffer: @[], capacity: capacity)

proc hasNext(stream: var MockStream): bool =
  stream.position < stream.items.len

proc next(stream: var MockStream): Future[Option[StreamItem]] {.async.} =
  ## Simulates awaitable stream reading with backpressure
  if not stream.hasNext():
    return none(StreamItem)

  # Simulate backpressure - wait if we're reading too fast
  await sleepAsync(50.milliseconds)

  let item = stream.items[stream.position]
  stream.position += 1
  return some(item)

proc send(sink: var MockSink, item: StreamItem): Future[void] {.async.} =
  ## Simulates awaitable sink writing with backpressure
  # Apply backpressure if buffer is full
  while sink.buffer.len >= sink.capacity:
    echo "Sink backpressure: buffer full, waiting..."
    await sleepAsync(100.milliseconds)

  sink.buffer.add(item)
  echo fmt"Sink buffered item {item.id}: {item.data} (buffer: {sink.buffer.len}/{sink.capacity})"

proc mapStream(stream: var MockStream, transform: proc(item: StreamItem): StreamItem): Future[seq[StreamItem]] {.async.} =
  ## Simulates stream map operation
  var results: seq[StreamItem] = @[]

  while stream.hasNext():
    let itemOpt = await stream.next()
    if itemOpt.isSome():
      let transformed = transform(itemOpt.get())
      results.add(transformed)

  return results

proc filterStream(items: seq[StreamItem], predicate: proc(item: StreamItem): bool): seq[StreamItem] =
  ## Simulates stream filter operation
  items.filter(predicate)

proc batchStream(items: seq[StreamItem], batchSize: int): seq[seq[StreamItem]] =
  ## Simulates stream batching operation
  var batches: seq[seq[StreamItem]] = @[]
  var currentBatch: seq[StreamItem] = @[]

  for item in items:
    currentBatch.add(item)
    if currentBatch.len >= batchSize:
      batches.add(currentBatch)
      currentBatch = @[]

  if currentBatch.len > 0:
    batches.add(currentBatch)

  return batches

proc throttleExample(items: seq[StreamItem], interval: Duration): Future[void] {.async.} =
  ## Demonstrates throttling stream operations
  echo "--- Throttled Processing ---"

  for i, item in items:
    echo fmt"Processing item {item.id}: {item.data}"

    # Throttle: wait before processing next item
    if i < items.len - 1:  # Don't wait after the last item
      await sleepAsync(interval)

proc pipelineExample() {.async.} =
  ## Demonstrates a complete stream processing pipeline
  echo "=== Stream Processing Pipeline ==="

  # Create source data
  let sourceData = @[
    StreamItem(id: 1, data: "apple", size: 5),
    StreamItem(id: 2, data: "banana", size: 6),
    StreamItem(id: 3, data: "cherry", size: 6),
    StreamItem(id: 4, data: "date", size: 4),
    StreamItem(id: 5, data: "elderberry", size: 10),
    StreamItem(id: 6, data: "fig", size: 3),
    StreamItem(id: 7, data: "grape", size: 5),
    StreamItem(id: 8, data: "honeydew", size: 8)
  ]

  echo fmt"Source data: {sourceData.len} items"

  # Create stream and sink
  var stream = newMockStream(sourceData, capacity = 3)
  var sink = newMockSink(capacity = 5)

  # Process with map operation
  echo "\n--- Map Operation (uppercase) ---"
  let mappedItems = await stream.mapStream(proc(item: StreamItem): StreamItem =
    StreamItem(
      id: item.id,
      data: item.data.toUpperAscii(),
      size: item.size
    )
  )

  # Filter operation
  echo "\n--- Filter Operation (size >= 5) ---"
  let filteredItems = filterStream(mappedItems, proc(item: StreamItem): bool =
    item.size >= 5
  )
  echo fmt"Filtered to {filteredItems.len} items: {filteredItems.mapIt(it.data)}"

  # Batch operation
  echo "\n--- Batch Operation (size 3) ---"
  let batches = batchStream(filteredItems, 3)
  echo fmt"Created {batches.len} batches"
  for i, batch in batches:
    echo fmt"Batch {i + 1}: {batch.mapIt(it.data)}"

  # Send to sink with backpressure
  echo "\n--- Sink Operations with Backpressure ---"
  for item in filteredItems:
    await sink.send(item)

  echo fmt"Final sink buffer: {sink.buffer.len} items"

  # Throttled processing
  echo "\n--- Throttled Processing (200ms intervals) ---"
  await throttleExample(filteredItems[0..2], 200.milliseconds)

proc backpressureDemo() {.async.} =
  ## Demonstrates backpressure handling
  echo "\n=== Backpressure Demonstration ==="

  var fastSink = newMockSink(capacity = 2)  # Small capacity for demo

  let items = @[
    StreamItem(id: 1, data: "fast1", size: 1),
    StreamItem(id: 2, data: "fast2", size: 1),
    StreamItem(id: 3, data: "fast3", size: 1),
    StreamItem(id: 4, data: "fast4", size: 1)
  ]

  echo "Sending items to sink with small capacity (backpressure will occur)..."

  # This will trigger backpressure as we exceed sink capacity
  for item in items:
    echo fmt"Attempting to send: {item.data}"
    await fastSink.send(item)

  echo "All items sent despite backpressure!"

proc main() {.async.} =
  echo "=== Streams with Backpressure Example ==="
  echo "Demonstrating planned API for stream processing with flow control"
  echo ""

  # Note: In the real implementation, this would use proper Stream[T]/Sink[T] types:
  # let (sink, stream) = channel[StreamItem](capacity = 64)
  # let processed = stream
  #   .map(proc(s: StreamItem): StreamItem = transform(s))
  #   .filter(proc(s: StreamItem): bool = predicate(s))
  #   .batch(32)
  #   .throttle(100.milliseconds)

  await pipelineExample()
  await backpressureDemo()

  echo "\nExample completed!"
  echo "\nIn the real implementation:"
  echo "- Stream operations would be fully awaitable"
  echo "- Backpressure would be handled automatically"
  echo "- Memory usage would be bounded by capacity limits"
  echo "- Cancellation would propagate through the pipeline"

when isMainModule:
  waitFor main()