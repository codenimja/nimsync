## File Processing Pipeline Example using nimsync
##
## Demonstrates:
## - Stream-based file processing with backpressure
## - Multi-stage processing pipeline
## - Error handling and recovery
## - Performance monitoring and throttling

import std/[os, strformat, times, strutils, json, math, algorithm]
import chronos
import ../../src/nimsync

type
  FileJob = object
    path: string
    size: int64
    priority: int
    metadata: Table[string, string]

  ProcessingResult = object
    inputPath: string
    outputPath: string
    operation: string
    processingTime: float64
    bytesProcessed: int64
    success: bool
    error: string

  ProcessingStats = object
    filesProcessed: int
    totalBytes: int64
    totalTime: float64
    errors: int

  FileProcessor = ref object
    inputStream: Stream[FileJob]
    outputStream: Stream[ProcessingResult]
    maxConcurrency: int
    batchSize: int
    stats: ProcessingStats

proc newFileProcessor*(maxConcurrency: int = 4, batchSize: int = 10): FileProcessor =
  FileProcessor(
    inputStream: initStream[FileJob](streams.BackpressurePolicy.Block),
    outputStream: initStream[ProcessingResult](streams.BackpressurePolicy.Block),
    maxConcurrency: maxConcurrency,
    batchSize: batchSize
  )

proc scanDirectory*(path: string, extensions: seq[string] = @[".txt", ".json", ".log"]): Future[seq[FileJob]] {.async.} =
  ## Scan directory for files to process
  echo fmt"📁 Scanning directory: {path}"
  var jobs: seq[FileJob] = @[]

  try:
    for file in walkDirRec(path):
      let ext = splitFile(file).ext.toLower()
      if ext in extensions:
        let info = getFileInfo(file)
        jobs.add(FileJob(
          path: file,
          size: info.size,
          priority: if ext == ".log": 1 else: 0,  # Prioritize log files
          metadata: {"extension": ext, "modified": $info.lastWriteTime}.toTable
        ))

  except OSError as e:
    echo fmt"❌ Directory scan error: {e.msg}"

  # Sort by priority (descending) then size (ascending)
  jobs.sort do (a, b: FileJob) -> int:
    if a.priority != b.priority:
      cmp(b.priority, a.priority)
    else:
      cmp(a.size, b.size)

  echo fmt"📋 Found {jobs.len} files to process"
  return jobs

proc processTextFile(job: FileJob): Future[ProcessingResult] {.async.} =
  ## Process a text file (word count, line count, etc.)
  let startTime = getMonoTime()
  var result = ProcessingResult(
    inputPath: job.path,
    operation: "text_analysis",
    success: false
  )

  try:
    let content = readFile(job.path)
    let lines = content.split('\n')
    let words = content.split({' ', '\t', '\n'}).filterIt(it.len > 0)

    # Simulate processing time based on file size
    await chronos.sleepAsync((job.size div 1000).milliseconds)

    # Create analysis result
    let analysis = %*{
      "file": job.path,
      "size_bytes": job.size,
      "lines": lines.len,
      "words": words.len,
      "characters": content.len,
      "avg_line_length": if lines.len > 0: content.len div lines.len else: 0
    }

    let outputPath = job.path & ".analysis.json"
    writeFile(outputPath, $analysis)

    result.outputPath = outputPath
    result.bytesProcessed = job.size
    result.success = true

  except CatchableError as e:
    result.error = e.msg

  let endTime = getMonoTime()
  result.processingTime = (endTime - startTime).inMilliseconds.float64 / 1000.0

  return result

proc processLogFile(job: FileJob): Future[ProcessingResult] {.async.} =
  ## Process a log file (extract errors, statistics)
  let startTime = getMonoTime()
  var result = ProcessingResult(
    inputPath: job.path,
    operation: "log_analysis",
    success: false
  )

  try:
    let content = readFile(job.path)
    let lines = content.split('\n')

    var errorCount = 0
    var warningCount = 0
    var infoCount = 0

    for line in lines:
      let lowerLine = line.toLower()
      if "error" in lowerLine:
        errorCount.inc
      elif "warning" in lowerLine or "warn" in lowerLine:
        warningCount.inc
      elif "info" in lowerLine:
        infoCount.inc

    # Simulate processing time
    await chronos.sleepAsync((job.size div 2000).milliseconds)

    let analysis = %*{
      "file": job.path,
      "total_lines": lines.len,
      "errors": errorCount,
      "warnings": warningCount,
      "info": infoCount,
      "severity_ratio": if lines.len > 0: errorCount.float64 / lines.len.float64 else: 0.0
    }

    let outputPath = job.path & ".log_analysis.json"
    writeFile(outputPath, $analysis)

    result.outputPath = outputPath
    result.bytesProcessed = job.size
    result.success = true

  except CatchableError as e:
    result.error = e.msg

  let endTime = getMonoTime()
  result.processingTime = (endTime - startTime).inMilliseconds.float64 / 1000.0

  return result

proc processFile(job: FileJob): Future[ProcessingResult] {.async.} =
  ## Process a single file based on its type
  let ext = splitFile(job.path).ext.toLower()

  case ext:
  of ".log":
    return await processLogFile(job)
  of ".txt", ".json":
    return await processTextFile(job)
  else:
    return ProcessingResult(
      inputPath: job.path,
      operation: "unknown",
      success: false,
      error: fmt"Unsupported file type: {ext}"
    )

proc worker(processor: FileProcessor, workerId: int): Future[void] {.async.} =
  ## Worker that processes files from the input stream
  echo fmt"🔧 Worker {workerId} started"

  try:
    while true:
      # Get job from input stream
      let job = await processor.inputStream.receive()

      echo fmt"⚙️  Worker {workerId} processing: {job.path} ({job.size} bytes)"

      # Process the file
      let result = await processFile(job)

      # Update stats
      processor.stats.filesProcessed.inc
      processor.stats.totalBytes += result.bytesProcessed
      processor.stats.totalTime += result.processingTime

      if not result.success:
        processor.stats.errors.inc
        echo fmt"❌ Worker {workerId} error: {result.error}"
      else:
        echo fmt"✅ Worker {workerId} completed: {result.outputPath} in {result.processingTime:.2f}s"

      # Send result to output stream
      await processor.outputStream.send(result)

  except ChannelClosedError:
    echo fmt"🛑 Worker {workerId} stopping (input stream closed)"
  except CatchableError as e:
    echo fmt"❌ Worker {workerId} error: {e.msg}"

proc resultCollector(processor: FileProcessor): Future[void] {.async.} =
  ## Collect and summarize processing results
  var results: seq[ProcessingResult] = @[]

  try:
    while true:
      let result = await processor.outputStream.receive()
      results.add(result)

      # Report progress every 10 files
      if results.len mod 10 == 0:
        let successful = results.countIt(it.success)
        let failed = results.len - successful
        echo fmt"📊 Progress: {results.len} files processed ({successful} success, {failed} failed)"

  except ChannelClosedError:
    echo "📋 Result collection finished"

    # Final summary
    let successful = results.filterIt(it.success)
    let failed = results.filterIt(not it.success)

    echo "\n📊 Processing Summary:"
    echo fmt"  Total files: {results.len}"
    echo fmt"  Successful: {successful.len}"
    echo fmt"  Failed: {failed.len}"

    if successful.len > 0:
      let avgTime = successful.mapIt(it.processingTime).sum / successful.len.float64
      let totalBytes = successful.mapIt(it.bytesProcessed).sum
      echo fmt"  Average processing time: {avgTime:.2f}s"
      echo fmt"  Total bytes processed: {totalBytes}"
      echo fmt"  Throughput: {totalBytes.float64 / processor.stats.totalTime:.0f} bytes/sec"

    if failed.len > 0:
      echo "\n❌ Failed files:"
      for result in failed:
        echo fmt"  {result.inputPath}: {result.error}"

proc feedJobs(processor: FileProcessor, jobs: seq[FileJob]): Future[void] {.async.} =
  ## Feed jobs to the processing pipeline
  echo fmt"📤 Feeding {jobs.len} jobs to processing pipeline..."

  try:
    for i, job in jobs:
      await processor.inputStream.send(job)

      # Add small delay to demonstrate backpressure
      if i mod processor.batchSize == 0:
        await chronos.sleepAsync(100.milliseconds)

  finally:
    # Close input stream to signal workers to stop
    processor.inputStream.close()

proc processDirectory*(processor: FileProcessor, directory: string): Future[void] {.async.} =
  ## Process all files in a directory using the pipeline
  echo fmt"🚀 Starting file processing pipeline for: {directory}"

  # Scan for files
  let jobs = await scanDirectory(directory)
  if jobs.len == 0:
    echo "📭 No files found to process"
    return

  # Start the processing pipeline
  await taskGroup:
    # Workers
    for i in 1..processor.maxConcurrency:
      discard g.spawn(proc(): Future[void] {.async.} =
        await processor.worker(i)
      )

    # Result collector
    discard g.spawn(proc(): Future[void] {.async.} =
        await processor.resultCollector()
    )

    # Job feeder
    discard g.spawn(proc(): Future[void] {.async.} =
      await processor.feedJobs(jobs)

      # Wait for all jobs to be processed
      await chronos.sleepAsync(2.seconds)

      # Close output stream
      processor.outputStream.close()
    )

proc createTestFiles*(directory: string): Future[void] {.async.} =
  ## Create test files for demonstration
  echo fmt"📝 Creating test files in: {directory}"

  try:
    createDir(directory)

    # Create sample text files
    for i in 1..5:
      let content = fmt"""
Sample text file {i}
This is a test file with multiple lines.
It contains various words and sentences.
Line count: approximately {i * 3} lines
Word count: approximately {i * 20} words
"""
      writeFile(joinPath(directory, fmt"sample_{i}.txt"), content)

    # Create sample log files
    for i in 1..3:
      var logContent = ""
      for j in 1..50:
        let level = case j mod 4:
          of 0: "ERROR"
          of 1: "WARNING"
          of 2: "INFO"
          else: "DEBUG"

        logContent.add(fmt"2025-01-01 12:{j:02d}:00 [{level}] Log message {j} from file {i}{'\n'}")

      writeFile(joinPath(directory, fmt"logfile_{i}.log"), logContent)

    # Create JSON files
    let jsonData = %*{
      "version": "1.0",
      "data": {
        "items": [1, 2, 3, 4, 5],
        "description": "Sample JSON file for processing"
      }
    }
    writeFile(joinPath(directory, "config.json"), $jsonData)

    echo "✅ Test files created successfully"

  except OSError as e:
    echo fmt"❌ Failed to create test files: {e.msg}"

proc main() {.async.} =
  echo "📁 File Processing Pipeline Example with nimsync"
  echo "================================================"

  let testDir = "./test_files"
  let processor = newFileProcessor(maxConcurrency = 3, batchSize = 5)

  try:
    # Create test files
    await createTestFiles(testDir)

    # Process the directory
    await processor.processDirectory(testDir)

    echo "\n🧹 Cleaning up test files..."
    removeDir(testDir)

  except CatchableError as e:
    echo fmt"❌ Error: {e.msg}"

  echo "\n✅ File processing pipeline example completed!"

when isMainModule:
  waitFor main()