## File Processing Scenario Test
## Demonstrates concurrent file processing using nimsync TaskGroup
## Mock data simulates processing multiple files with different operations

import nimsync
import std/[os, strutils, random, tables]

type
  MockFile = object
    name: string
    content: string
    size: int

  ProcessingResult = object
    fileName: string
    wordCount: int
    processedSize: int
    checksum: string

proc generateMockFiles(count: int): seq[MockFile] =
  ## Generate mock file data
  for i in 1..count:
    let content = "Mock file content " & $i & " with some random text " & $rand(1000..9999)
    result.add MockFile(
      name: "file_" & $i & ".txt",
      content: content,
      size: content.len
    )

proc processFile(file: MockFile): Future[ProcessingResult] {.async.} =
  ## Simulate file processing: word count, size calculation, checksum
  await sleepAsync(rand(10..50).milliseconds)  # Simulate processing time

  let words = file.content.splitWhitespace()
  let checksum = "mock_checksum_" & $file.size.hash

  return ProcessingResult(
    fileName: file.name,
    wordCount: words.len,
    processedSize: file.size,
    checksum: checksum
  )

proc concurrentFileProcessingScenario*() {.async.} =
  ## Main test scenario: Process multiple files concurrently
  echo "Starting concurrent file processing scenario..."

  # Generate mock files
  let mockFiles = generateMockFiles(20)

  # Results collection
  var results: seq[ProcessingResult]

  # Use TaskGroup for concurrent processing
  await taskGroup:
    for file in mockFiles:
      proc process(file: MockFile) {.async.} =
        let result = await processFile(file)
        results.add result
        echo &"Processed {result.fileName}: {result.wordCount} words, {result.processedSize} bytes"
      discard g.spawn process(file)

  # Aggregate results
  var totalWords = 0
  var totalSize = 0
  var checksums: Table[string, int]

  for result in results:
    totalWords += result.wordCount
    totalSize += result.processedSize
    checksums[result.checksum] = checksums.getOrDefault(result.checksum, 0) + 1

  echo "\nProcessing summary:"
  echo &"  Total files: {results.len}"
  echo &"  Total words: {totalWords}"
  echo &"  Total size: {totalSize} bytes"
  echo &"  Unique checksums: {checksums.len}"

  echo "File processing scenario completed."

when isMainModule:
  waitFor concurrentFileProcessingScenario()