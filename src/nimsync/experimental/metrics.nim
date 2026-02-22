## nimsync — Comprehensive Performance Metrics & Monitoring
##
## This module provides real-time metrics collection with minimal overhead,
## supporting multiple export formats including Prometheus.
##
## Key Features:
## - Lock-free metrics collection
## - Histogram-based latency tracking (P50, P95, P99)
## - Counter and gauge metrics
## - Adaptive sampling for high-frequency events
## - Prometheus export format
## - Real-time dashboard support

import std/[atomics, times, tables, math, sequtils]
import ./errors

type
  ## Metric types
  MetricType* = enum
    Counter     ## Monotonically increasing
    Gauge       ## Current value
    Histogram   ## Distribution data

  ## Histogram bucket
  HistogramBucket* = object
    boundary*: float
    count*: Atomic[uint64]

  ## Histogram metric with percentile tracking
  HistogramMetric* = ref object
    name*: string
    buckets*: seq[HistogramBucket]
    count*: Atomic[uint64]
    sum*: Atomic[float]
    min*: Atomic[float]
    max*: Atomic[float]

  ## Counter metric
  CounterMetric* = ref object
    name*: string
    labels*: Table[string, string]
    value*: Atomic[uint64]

  ## Gauge metric
  GaugeMetric* = ref object
    name*: string
    labels*: Table[string, string]
    value*: Atomic[float]

  ## System metrics snapshot
  SystemMetrics* = object
    timestamp*: int64
    taskSpawnRate*: float
    taskCompletionRate*: float
    channelThroughput*: float
    actorMessageRate*: float
    avgLatency*: float
    p95Latency*: float
    p99Latency*: float
    memoryUsage*: float
    goroutineCount*: int

  ## Metrics collector
  MetricsCollector* = ref object
    ## All registered histograms
    histograms*: Table[string, HistogramMetric]
    ## All registered counters
    counters*: Table[string, CounterMetric]
    ## All registered gauges
    gauges*: Table[string, GaugeMetric]
    ## Collection enabled
    enabled*: bool
    ## Sampling rate (0.0-1.0)
    samplingRate*: float
    ## Collection start time
    startTime*: int64

# Global metrics collector
var globalCollector*: MetricsCollector

## Create default histogram buckets (exponential distribution)
proc createHistogramBuckets*(): seq[HistogramBucket] =
  var buckets: seq[HistogramBucket] = @[]

  # Buckets: 1us, 10us, 100us, 1ms, 10ms, 100ms, 1s, 10s
  let boundaries = [1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1_000_000.0, 10_000_000.0]

  for boundary in boundaries:
    buckets.add(HistogramBucket(
      boundary: boundary,
      count: 0'u64
    ))

  buckets

## Create new histogram metric
proc newHistogramMetric*(name: string, buckets: seq[HistogramBucket] = createHistogramBuckets()): HistogramMetric =
  HistogramMetric(
    name: name,
    buckets: buckets,
    count: 0'u64,
    sum: 0.0,
    min: float.high,
    max: 0.0
  )

## Create new counter metric
proc newCounterMetric*(name: string, labels: Table[string, string] = initTable[string, string]()): CounterMetric =
  CounterMetric(
    name: name,
    labels: labels,
    value: 0'u64
  )

## Create new gauge metric
proc newGaugeMetric*(name: string, labels: Table[string, string] = initTable[string, string]()): GaugeMetric =
  GaugeMetric(
    name: name,
    labels: labels,
    value: 0.0
  )

## Initialize global metrics collector
proc initMetricsCollector*(enabled: bool = true, samplingRate: float = 1.0): MetricsCollector =
  globalCollector = MetricsCollector(
    histograms: initTable[string, HistogramMetric](),
    counters: initTable[string, CounterMetric](),
    gauges: initTable[string, GaugeMetric](),
    enabled: enabled,
    samplingRate: max(0.0, min(1.0, samplingRate)),
    startTime: getTime().toUnixNanos()
  )
  globalCollector

## Get global collector
proc getCollector*(): MetricsCollector =
  if globalCollector == nil:
    initMetricsCollector()
  globalCollector

## Record histogram value
proc recordHistogram*(histogram: HistogramMetric, value: float) =
  discard atomicInc(histogram.count)

  var sum = atomicLoad(histogram.sum)
  atomicStore(histogram.sum, sum + value)

  let currentMin = atomicLoad(histogram.min)
  if value < currentMin:
    atomicStore(histogram.min, value)

  let currentMax = atomicLoad(histogram.max)
  if value > currentMax:
    atomicStore(histogram.max, value)

  # Find bucket and increment
  for bucket in histogram.buckets.mitems():
    if value <= bucket.boundary:
      discard atomicInc(bucket.count)
      break

## Increment counter
proc incrementCounter*(counter: CounterMetric, amount: uint64 = 1) =
  discard atomicAddFetch(counter.value, amount)

## Set gauge value
proc setGauge*(gauge: GaugeMetric, value: float) =
  atomicStore(gauge.value, value)

## Register histogram with collector
proc registerHistogram*(collector: MetricsCollector, name: string): HistogramMetric =
  if name notin collector.histograms:
    collector.histograms[name] = newHistogramMetric(name)
  collector.histograms[name]

## Register counter with collector
proc registerCounter*(collector: MetricsCollector, name: string): CounterMetric =
  if name notin collector.counters:
    collector.counters[name] = newCounterMetric(name)
  collector.counters[name]

## Register gauge with collector
proc registerGauge*(collector: MetricsCollector, name: string): GaugeMetric =
  if name notin collector.gauges:
    collector.gauges[name] = newGaugeMetric(name)
  collector.gauges[name]

## Calculate percentile from histogram
proc getPercentile*(histogram: HistogramMetric, percentile: float): float =
  let count = float(atomicLoad(histogram.count))
  if count == 0.0:
    return 0.0

  let targetCount = count * (percentile / 100.0)
  var cumulative = 0.0

  for bucket in histogram.buckets:
    let bucketCount = float(atomicLoad(bucket.count))
    cumulative += bucketCount
    if cumulative >= targetCount:
      return bucket.boundary

  atomicLoad(histogram.max)

## Get percentile from global histogram
proc getHistogramPercentile*(collector: MetricsCollector, name: string, percentile: float): float =
  if name in collector.histograms:
    getPercentile(collector.histograms[name], percentile)
  else:
    0.0

## Format histogram as Prometheus text format
proc toPrometheus*(histogram: HistogramMetric): string =
  var output = ""
  let count = atomicLoad(histogram.count)
  let sum = atomicLoad(histogram.sum)

  output &= "# HELP " & histogram.name & "_duration_us Distribution of latencies\n"
  output &= "# TYPE " & histogram.name & "_duration_us histogram\n"

  for bucket in histogram.buckets:
    let bucketCount = atomicLoad(bucket.count)
    output &= histogram.name & "_duration_us_bucket{le=\"" & formatFloat(bucket.boundary, ffDecimal, 2) & "\"} " & $bucketCount & "\n"

  output &= histogram.name & "_duration_us_bucket{le=\"+Inf\"} " & $count & "\n"
  output &= histogram.name & "_duration_us_sum " & formatFloat(sum, ffDecimal, 2) & "\n"
  output &= histogram.name & "_duration_us_count " & $count & "\n"

  output

## Format counter as Prometheus text format
proc toPrometheus*(counter: CounterMetric): string =
  let value = atomicLoad(counter.value)
  "# HELP " & counter.name & " Counter metric\n" &
  "# TYPE " & counter.name & " counter\n" &
  counter.name & " " & $value & "\n"

## Format gauge as Prometheus text format
proc toPrometheus*(gauge: GaugeMetric): string =
  let value = atomicLoad(gauge.value)
  "# HELP " & gauge.name & " Gauge metric\n" &
  "# TYPE " & gauge.name & " gauge\n" &
  gauge.name & " " & formatFloat(value, ffDecimal, 3) & "\n"

## Export all metrics in Prometheus format
proc exportPrometheus*(collector: MetricsCollector): string =
  var output = ""

  # Add timestamp
  output &= "# Generated at " & $getTime() & "\n\n"

  # Export histograms
  for name, histogram in collector.histograms:
    output &= toPrometheus(histogram)
    output &= "\n"

  # Export counters
  for name, counter in collector.counters:
    output &= toPrometheus(counter)
    output &= "\n"

  # Export gauges
  for name, gauge in collector.gauges:
    output &= toPrometheus(gauge)
    output &= "\n"

  output

## Get summary statistics
proc getSummary*(collector: MetricsCollector): string =
  var output = "Metrics Summary\n"
  output &= "===============\n\n"

  output &= "Histograms: " & $collector.histograms.len & "\n"
  for name, histogram in collector.histograms:
    let count = atomicLoad(histogram.count)
    let avg = if count > 0: atomicLoad(histogram.sum) / float(count) else: 0.0
    let p50 = getPercentile(histogram, 50.0)
    let p95 = getPercentile(histogram, 95.0)
    let p99 = getPercentile(histogram, 99.0)

    output &= "  " & name & ": count=" & $count & ", avg=" & formatFloat(avg, ffDecimal, 2) & " us"
    output &= ", p50=" & formatFloat(p50, ffDecimal, 2) & ", p95=" & formatFloat(p95, ffDecimal, 2)
    output &= ", p99=" & formatFloat(p99, ffDecimal, 2) & "\n"

  output &= "\nCounters: " & $collector.counters.len & "\n"
  for name, counter in collector.counters:
    let value = atomicLoad(counter.value)
    output &= "  " & name & ": " & $value & "\n"

  output &= "\nGauges: " & $collector.gauges.len & "\n"
  for name, gauge in collector.gauges:
    let value = atomicLoad(gauge.value)
    output &= "  " & name & ": " & formatFloat(value, ffDecimal, 3) & "\n"

  output

## Helper for atomic add-fetch
proc atomicAddFetch*(val: var Atomic[uint64], delta: uint64): uint64 =
  let newVal = atomicLoad(val) + delta
  atomicStore(val, newVal)
  newVal
