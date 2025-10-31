#!/usr/bin/env -S nim r -d:danger --opt:speed

## Comprehensive Benchmark Runner for nimsync
## 
## This script runs all available benchmarks and stores results in an organized structure.
##
## Usage:
##   nim r scripts/run_all_benchmarks.nims
##
## Results will be stored in:
##   - benchmarks/results/ - Benchmark execution results
##   - benchmarks/data/    - Raw benchmark data files
##   - benchmarks/reports/ - Generated performance reports
##   - benchmarks/logs/    - Benchmark execution logs

import std/[os, times, strformat, sequtils, json, sugar]

# Directory paths
const BENCHMARKS_DIR = "benchmarks"
const RESULTS_DIR = "benchmarks/results"
const DATA_DIR = "benchmarks/data"
const REPORTS_DIR = "benchmarks/reports"
const LOGS_DIR = "benchmarks/logs"

type
  BenchmarkResult = object
    name*: string
    duration*: float    # in seconds
    throughput*: float  # ops/sec if applicable
    memory*: int        # memory usage if applicable
    status*: string     # "passed", "failed", "timeout"
    error*: string      # error message if failed

proc ensureDirectories() =
  ## Create necessary directories if they don't exist
  for dir in [RESULTS_DIR, DATA_DIR, REPORTS_DIR, LOGS_DIR]:
    createDir(dir)

proc runBenchmark(name: string, executable: string, args: string = ""): BenchmarkResult =
  ## Run a single benchmark and return results
  let startTime = cpuTime()
  let timestamp = format(now(), "yyyy-MM-dd_HH-mm-ss")
  let logFile = fmt"{LOGS_DIR}/{name}_{timestamp}.log"
  
  echo fmt"🏃 Running {name} benchmark..."
  
  try:
    let cmd = if args.len > 0: fmt"{executable} {args} | tee {logFile}"
              else: fmt"{executable} | tee {logFile}"
    
    let exitCode = execShellCmd(cmd)
    
    let duration = cpuTime() - startTime
    
    result = BenchmarkResult(
      name: name,
      duration: duration,
      status: if exitCode == 0: "passed" else: "failed",
      error: if exitCode != 0: fmt"Exit code: {exitCode}" else: ""
    )
    
    echo fmt"✅ {name} completed in {duration:.2f}s"
  
  except Exception as e:
    let duration = cpuTime() - startTime
    result = BenchmarkResult(
      name: name,
      duration: duration,
      status: "failed",
      error: e.msg
    )
    echo fmt"❌ {name} failed: {e.msg}"

proc compileAndRunBenchmark(benchmarkFile: string, name: string): BenchmarkResult =
  ## Compile and run a benchmark Nim file
  let startTime = cpuTime()
  let timestamp = format(now(), "yyyy-MM-dd_HH-mm-ss")
  let logFile = fmt"{LOGS_DIR}/{name}_{timestamp}.log"
  let executable = benchmarkFile.replace(".nim", "")
  
  echo fmt"🔨 Compiling {benchmarkFile}..."
  
  # Compile the benchmark
  let compileCmd = fmt"nim c -d:danger --opt:speed {benchmarkFile} 2>&1 | tee -a {logFile}"
  let compileResult = execShellCmd(compileCmd)
  
  if compileResult != 0:
    return BenchmarkResult(
      name: name,
      duration: cpuTime() - startTime,
      status: "failed",
      error: "Compilation failed"
    )
  
  echo fmt"🏃 Running {name} benchmark..."
  
  # Run the benchmark
  let runCmd = fmt"./{executable} 2>&1 | tee -a {logFile}"
  let runResult = execShellCmd(runCmd)
  
  # Clean up executable
  if fileExists(executable):
    removeFile(executable)
  
  let duration = cpuTime() - startTime
  
  result = BenchmarkResult(
    name: name,
    duration: duration,
    status: if runResult == 0: "passed" else: "failed",
    error: if runResult != 0: fmt"Exit code: {runResult}" else: ""
  )
  
  echo fmt"✅ {name} completed in {duration:.2f}s"

proc runAllBenchmarks() {.async.} =
  ## Run all available benchmarks and collect results
  ensureDirectories()
  
  let timestamp = format(now(), "yyyyMMdd_HHmmss")
  var allResults: seq[BenchmarkResult] = @[]
  
  echo "🚀 Starting nimsync Comprehensive Benchmark Suite"
  echo fmt"📅 Timestamp: {timestamp}"
  echo fmt"💻 System: {getAppFilename()}"
  echo ""
  
  # Core benchmarks from benchmarks/ directory
  let coreBenchmarks = @[
    ("basic_async_benchmark.nim", "Basic Async Operations"),
    ("channels_benchmark.nim", "Channel Throughput"),
    ("taskgroup_benchmark.nim", "TaskGroup Performance"),
    ("streams_benchmark.nim", "Stream Processing"),
    ("full_system_benchmark.nim", "Full System Integration")
  ]
  
  for (file, name) in coreBenchmarks:
    let fullPath = fmt"benchmarks/{file}"
    if fileExists(fullPath):
      let result = compileAndRunBenchmark(fullPath, name)
      allResults.add(result)
    else:
      echo fmt"⚠️  Skipping {name} - file not found: {fullPath}"
  
  # Performance tests
  let perfTests = @[
    ("tests/performance/benchmark_stress.nim", "Performance Stress Test"),
    ("tests/performance/test_benchmarks.nim", "Performance Suite")
  ]
  
  for (file, name) in perfTests:
    if fileExists(file):
      let result = compileAndRunBenchmark(file, name)
      allResults.add(result)
    else:
      echo fmt"⚠️  Skipping {name} - file not found: {file}"
  
  # Stress tests
  let stressTests = @[
    ("tests/stress/extreme_stress_test.nim", "Extreme Stress Test"),
    ("tests/stress/stress_test_select.nim", "Stress Select Test")
  ]
  
  for (file, name) in stressTests:
    if fileExists(file):
      let result = compileAndRunBenchmark(file, name)
      allResults.add(result)
    else:
      echo fmt"⚠️  Skipping {name} - file not found: {file}"
  
  # Additional benchmarks
  let additionalBenchmarks = @[
    ("bench_select.nim", "Select Operations Benchmark")
  ]
  
  for (file, name) in additionalBenchmarks:
    if fileExists(file):
      let result = compileAndRunBenchmark(file, name)
      allResults.add(result)
    else:
      echo fmt"⚠️  Skipping {name} - file not found: {file}"
  
  # Calculate summary
  let passedCount = allResults.countIt(it.status == "passed")
  let failedCount = allResults.countIt(it.status == "failed")
  let totalDuration = allResults.foldl(a.duration + b.duration)
  
  # Generate summary report
  let reportFile = fmt"{REPORTS_DIR}/benchmark_summary_{timestamp}.md"
  var reportContent = fmt"""
# nimsync Benchmark Summary
Date: {now()}
System: { gorge("uname -a", "").strip() }
Nim Version: { gorge("nim --version", "").lines().toSeq()[0] }
nimsync Version: { gorge("grep version nimsync.nimble | head -1 | cut -d '\\' -f 2", "").strip() }

## Benchmark Results
- Total Benchmarks Run: {allResults.len}
- Passed: {passedCount}
- Failed: {failedCount}
- Total Duration: {totalDuration:.2f}s

## Detailed Results
"""
  
  for result in allResults:
    reportContent.add(fmt"""
### {result.name}
- Status: {result.status}
- Duration: {result.duration:.2f}s
- Error: {if result.error.len > 0: result.error else: "None"}
""")

  writeFile(reportFile, reportContent)
  
  # Generate JSON report for programmatic access
  let jsonReportFile = fmt"{REPORTS_DIR}/benchmark_results_{timestamp}.json"
  var jsonResults: seq[JsonNode] = @[]
  
  for result in allResults:
    jsonResults.add(%* {
      "name": result.name,
      "duration": result.duration,
      "status": result.status,
      "error": result.error
    })
  
  let jsonReport = %* {
    "timestamp": timestamp,
    "totalBenchmarks": allResults.len,
    "passed": passedCount,
    "failed": failedCount,
    "totalDuration": totalDuration,
    "benchmarks": jsonResults
  }
  
  writeFile(jsonReportFile, $jsonReport)
  
  # Print summary to console
  echo ""
  echo "📊 BENCHMARK SUITE RESULTS SUMMARY"
  echo fmt"{'Benchmark':<30} {'Status':<10} {'Duration (s)':<12}"
  echo fmt"{'-' * 52}"
  for result in allResults:
    let statusMark = if result.status == "passed": "✅ PASSED" else: "❌ FAILED"
    echo fmt"{' '}{result.name:<29} {statusMark:<10} {result.duration:<12.2f}"
  echo fmt"{'-' * 52}"
  let totalStatus = if failedCount == 0: "✅ PASSED" else: "❌ FAILED"
  echo fmt"{'Total':<30} {totalStatus:<10} {totalDuration:<12.2f}"
  
  echo ""
  echo fmt"✅ Report saved to: {reportFile}"
  echo fmt"📄 JSON data saved to: {jsonReportFile}"
  echo fmt"📋 Logs saved to: {LOGS_DIR}/"
  
  if failedCount > 0:
    echo fmt"⚠️  {failedCount} benchmark(s) failed - check logs in {LOGS_DIR}/"
    quit(1)
  else:
    echo "🎉 All benchmarks completed successfully!"

when isMainModule:
  waitFor runAllBenchmarks()