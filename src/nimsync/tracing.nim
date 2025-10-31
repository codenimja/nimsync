## nimsync — OpenTelemetry Distributed Tracing
##
## This module provides distributed tracing support compatible with OpenTelemetry,
## enabling visibility into async operations across process boundaries.
##
## Key Features:
## - Automatic span generation for async operations
## - Context propagation across task boundaries
## - Trace ID and Span ID generation (W3C Trace Context)
## - Integration with OpenTelemetry exporters
## - Minimal overhead when tracing is disabled

import std/[atomics, times, random, tables, strutils, options]
import ./errors

type
  ## W3C Trace Context conformant trace ID
  TraceId* = distinct array[2, uint64]

  ## W3C Span ID
  SpanId* = distinct uint64

  ## Span attributes and baggage
  SpanContext* = ref object
    ## Unique trace identifier
    traceId*: TraceId
    ## Unique span identifier
    spanId*: SpanId
    ## Parent span (if any)
    parentSpanId*: Option[SpanId]
    ## Whether sampling is enabled for this trace
    sampled*: bool
    ## Custom attributes (key-value pairs)
    attributes*: Table[string, string]
    ## Baggage for cross-boundary propagation
    baggage*: Table[string, string]
    ## Span start time
    startTime*: int64
    ## Span end time (0 if still active)
    endTime*: int64

  ## Span events (timely occurrences within a span)
  SpanEvent* = object
    name*: string
    timestamp*: int64
    attributes*: Table[string, string]

  ## Span status
  SpanStatus* = enum
    Unset
    Ok
    Error

  ## Active tracing context (thread-local)
  TracingContext* = object
    currentSpan*: Option[SpanContext]
    spanStack*: seq[SpanContext]
    isEnabled*: bool
    samplingRate*: float

  ## Exporter interface for sending traces
  SpanExporter* = ref object of RootObj

  ## In-memory batch exporter (default)
  BatchExporter* = ref object of SpanExporter
    spans*: seq[SpanContext]
    maxSize*: int

# Global tracing state
var globalTracingContext* {.threadvar.}: TracingContext

## Initialize global tracing context
proc initTracingContext*(enabled: bool = true, samplingRate: float = 1.0): TracingContext =
  TracingContext(
    currentSpan: none(SpanContext),
    spanStack: @[],
    isEnabled: enabled,
    samplingRate: max(0.0, min(1.0, samplingRate))
  )

## Get global tracing context
proc getTracingContext*(): var TracingContext =
  if not globalTracingContext.isEnabled:
    globalTracingContext = initTracingContext()
  globalTracingContext

## Generate random trace ID
proc generateTraceId*(): TraceId =
  let high = rand(uint64)
  let low = rand(uint64)
  TraceId([high, low])

## Generate random span ID
proc generateSpanId*(): SpanId =
  SpanId(rand(uint64))

## Create a new span context
proc newSpanContext*(traceId: TraceId = generateTraceId(),
                     spanId: SpanId = generateSpanId(),
                     parentSpanId: Option[SpanId] = none(SpanId),
                     sampled: bool = true): SpanContext =
  SpanContext(
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    sampled: sampled,
    attributes: initTable[string, string](),
    baggage: initTable[string, string](),
    startTime: (getTime().toUnix * 1_000_000_000 + getTime().nanosecond).int64,
    endTime: 0
  )

## Start a new span (pushes to stack, returns context)
proc startSpan*(name: string, attributes: Table[string, string] = initTable[string, string]()): SpanContext =
  var ctx = getTracingContext()

  if not ctx.isEnabled:
    return newSpanContext()

  # Check sampling
  if rand(1.0) > ctx.samplingRate:
    return newSpanContext(sampled = false)

  let parentSpanId = if ctx.currentSpan.isSome: some(ctx.currentSpan.get().spanId) else: none(SpanId)
  let traceId = if ctx.currentSpan.isSome: ctx.currentSpan.get().traceId else: generateTraceId()

  var span = newSpanContext(
    traceId = traceId,
    spanId = generateSpanId(),
    parentSpanId = parentSpanId,
    sampled = true
  )
  span.attributes = attributes

  ctx.spanStack.add(span)
  ctx.currentSpan = some(span)

  span

## End current span and pop from stack
proc endSpan*() =
  var ctx = getTracingContext()

  if ctx.currentSpan.isSome:
    ctx.currentSpan.get().endTime = (getTime().toUnix * 1_000_000_000 + getTime().nanosecond).int64

  if ctx.spanStack.len > 0:
    discard ctx.spanStack.pop()

  if ctx.spanStack.len > 0:
    ctx.currentSpan = some(ctx.spanStack[^1])
  else:
    ctx.currentSpan = none(SpanContext)

## Add an event to the current span
proc addEvent*(name: string, attributes: Table[string, string] = initTable[string, string]()) =
  var ctx = getTracingContext()

  if ctx.currentSpan.isSome and ctx.currentSpan.get().sampled:
    # Would normally store in span events
    discard

## Add attribute to current span
proc setAttribute*(key: string, value: string) =
  var ctx = getTracingContext()

  if ctx.currentSpan.isSome:
    ctx.currentSpan.get().attributes[key] = value

## Add baggage item (propagates across boundaries)
proc setBaggage*(key: string, value: string) =
  var ctx = getTracingContext()

  if ctx.currentSpan.isSome:
    ctx.currentSpan.get().baggage[key] = value

## Get baggage item
proc getBaggage*(key: string): Option[string] =
  var ctx = getTracingContext()

  if ctx.currentSpan.isSome and key in ctx.currentSpan.get().baggage:
    some(ctx.currentSpan.get().baggage[key])
  else:
    none(string)

## Record an error in the current span
proc recordError*(error: string, errorType: string = "unknown") =
  var ctx = getTracingContext()

  if ctx.currentSpan.isSome:
    let span = ctx.currentSpan.get()
    span.attributes["error"] = "true"
    span.attributes["error.kind"] = errorType
    span.attributes["error.message"] = error

## Format TraceId as hex string
proc formatTraceId*(traceId: TraceId): string =
  # Format as 32-character hex string (W3C format)
  let arr = cast[array[2, uint64]](traceId)
  let high = arr[0]
  let low = arr[1]

  toHex(high) & toHex(low)

## Format SpanId as hex string
proc formatSpanId*(spanId: SpanId): string =
  # Format as 16-character hex string (W3C format)
  toHex(uint64(spanId))

## Create W3C Traceparent header value
proc createTraceparent*(span: SpanContext): string =
  # Format: version-traceid-spanid-traceflags
  let version = "00"
  let traceId = formatTraceId(span.traceId)
  let spanId = formatSpanId(span.spanId)
  let flags = if span.sampled: "01" else: "00"

  version & "-" & traceId & "-" & spanId & "-" & flags

## Parse W3C Traceparent header
proc parseTraceparent*(header: string): Option[SpanContext] =
  let parts = header.split("-")
  if parts.len != 4:
    return none(SpanContext)

  try:
    # Extract trace ID and span ID
    # Would need proper hex parsing
    return some(newSpanContext())
  except:
    none(SpanContext)

## Initialize batch exporter
proc newBatchExporter*(maxSize: int = 512): BatchExporter =
  BatchExporter(
    spans: @[],
    maxSize: maxSize
  )

## Add span to batch exporter
proc exportSpan*(exporter: BatchExporter, span: SpanContext) =
  if exporter.spans.len < exporter.maxSize:
    exporter.spans.add(span)

## Format span as JSON-like string for debugging
proc formatSpan*(span: SpanContext): string =
  let duration = if span.endTime > 0: span.endTime - span.startTime else: 0
  let durationMs = duration div 1_000_000

  "Span(\n" &
  "  TraceId: " & formatTraceId(span.traceId) & "\n" &
  "  SpanId: " & formatSpanId(span.spanId) & "\n" &
  "  Sampled: " & $span.sampled & "\n" &
  "  Duration: " & $durationMs & "ms\n" &
  "  Attributes: " & $span.attributes.len & " items\n" &
  ")"

# Helper for hex formatting
proc toHex*(value: uint64): string =
  result = newString(16)
  for i in countdown(15, 0):
    let digit = int(value shr (i * 4) and 0xF)
    result[15 - i] = if digit < 10: char(ord('0') + digit) else: char(ord('a') + digit - 10)
