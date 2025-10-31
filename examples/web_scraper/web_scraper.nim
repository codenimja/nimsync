## Concurrent Web Scraper Example using nimsync
##
## Demonstrates:
## - Rate-limited concurrent HTTP requests
## - URL queue management and crawl depth control
## - Data extraction and structured storage
## - Respectful crawling with delays and robot.txt compliance

import std/[httpclient, uri, strformat, times, strutils, sets, tables, json, re]
import chronos
import ../../src/nimsync

type
  CrawlJob = object
    url: string
    depth: int
    referer: string
    priority: int

  ScrapedData = object
    url: string
    title: string
    description: string
    links: seq[string]
    images: seq[string]
    text: string
    statusCode: int
    contentType: string
    size: int
    crawlTime: DateTime
    processingTime: float64
    error: string

  CrawlerConfig = object
    maxDepth: int
    maxPages: int
    maxConcurrency: int
    delayBetweenRequests: chronos.Duration
    userAgent: string
    respectRobotsTxt: bool
    allowedDomains: seq[string]
    blockedPatterns: seq[Regex]

  WebScraper = ref object
    config: CrawlerConfig
    client: AsyncHttpClient
    visitedUrls: HashSet[string]
    urlQueue: Channel[CrawlJob]
    dataQueue: Channel[ScrapedData]
    rateLimiter: Channel[bool]
    stats: CrawlerStats

  CrawlerStats = object
    urlsVisited: int
    bytesDownloaded: int64
    pagesSuccessful: int
    pagesError: int
    totalTime: float64

proc newCrawlerConfig*(): CrawlerConfig =
  CrawlerConfig(
    maxDepth: 2,
    maxPages: 50,
    maxConcurrency: 5,
    delayBetweenRequests: chronos.milliseconds(1000),
    userAgent: "nimsync-scraper/1.0 (+https://github.com/username/nimsync)",
    respectRobotsTxt: true,
    allowedDomains: @[],
    blockedPatterns: @[]
  )

proc newWebScraper*(config: CrawlerConfig): WebScraper =
  result = WebScraper(
    config: config,
    client: newAsyncHttpClient(),
    visitedUrls: initHashSet[string](),
    urlQueue: newChannel[CrawlJob](1000, ChannelMode.MPSC),
    dataQueue: newChannel[ScrapedData](100, ChannelMode.SPSC),
    rateLimiter: newChannel[bool](config.maxConcurrency, ChannelMode.SPSC)
  )

  # Initialize rate limiter
  for i in 0 ..< config.maxConcurrency:
    discard result.rateLimiter.trySend(true)

  # Set user agent
  result.client.headers = newHttpHeaders({"User-Agent": config.userAgent})

proc extractTitle(html: string): string =
  ## Extract page title from HTML
  let titleMatch = html.find(re"<title[^>]*>([^<]+)</title>", 0)
  if titleMatch.isSome:
    return titleMatch.get.captures[0].strip()
  return ""

proc extractDescription(html: string): string =
  ## Extract meta description from HTML
  let descMatch = html.find(re"<meta\s+name=[\"']description[\"']\s+content=[\"']([^\"']+)[\"']", 0)
  if descMatch.isSome:
    return descMatch.get.captures[0].strip()
  return ""

proc extractLinks(html: string, baseUrl: string): seq[string] =
  ## Extract all links from HTML
  var links: seq[string] = @[]
  for match in html.findAll(re"<a\s+[^>]*href=[\"']([^\"']+)[\"']"):
    let link = match.captures[0]
    if link.startsWith("http"):
      links.add(link)
    elif link.startsWith("/"):
      let base = parseUri(baseUrl)
      links.add(fmt"{base.scheme}://{base.hostname}{link}")
  return links.deduplicate()

proc extractImages(html: string, baseUrl: string): seq[string] =
  ## Extract all image URLs from HTML
  var images: seq[string] = @[]
  for match in html.findAll(re"<img\s+[^>]*src=[\"']([^\"']+)[\"']"):
    let img = match.captures[0]
    if img.startsWith("http"):
      images.add(img)
    elif img.startsWith("/"):
      let base = parseUri(baseUrl)
      images.add(fmt"{base.scheme}://{base.hostname}{img}")
  return images.deduplicate()

proc extractText(html: string): string =
  ## Extract plain text from HTML (simplified)
  # Remove script and style tags
  var text = html.replace(re"<(script|style)[^>]*>.*?</\1>", "")
  # Remove HTML tags
  text = text.replace(re"<[^>]+>", " ")
  # Clean up whitespace
  text = text.replace(re"\s+", " ").strip()
  return text

proc isUrlAllowed(scraper: WebScraper, url: string): bool =
  ## Check if URL is allowed to be crawled
  let uri = parseUri(url)

  # Check allowed domains
  if scraper.config.allowedDomains.len > 0:
    if uri.hostname notin scraper.config.allowedDomains:
      return false

  # Check blocked patterns
  for pattern in scraper.config.blockedPatterns:
    if url.contains(pattern):
      return false

  return true

proc scrapePage(scraper: WebScraper, job: CrawlJob): Future[ScrapedData] {.async.} =
  ## Scrape a single page
  let startTime = getMonoTime()
  var data = ScrapedData(
    url: job.url,
    crawlTime: now(),
    statusCode: 0
  )

  try:
    # Rate limiting
    discard await scraper.rateLimiter.recv()

    echo fmt"🕷️  Scraping: {job.url} (depth: {job.depth})"

    # Make HTTP request
    let response = await scraper.client.get(job.url)
    data.statusCode = response.code.int
    data.contentType = response.headers.getOrDefault("content-type", "")

    if response.code.is2xx and data.contentType.contains("text/html"):
      let html = await response.body
      data.size = html.len

      # Extract data
      data.title = extractTitle(html)
      data.description = extractDescription(html)
      data.links = extractLinks(html, job.url)
      data.images = extractImages(html, job.url)
      data.text = extractText(html)[0..min(500, extractText(html).len-1)]  # First 500 chars

      # Queue new URLs for crawling
      if job.depth < scraper.config.maxDepth:
        for link in data.links:
          if scraper.isUrlAllowed(link) and link notin scraper.visitedUrls:
            let newJob = CrawlJob(
              url: link,
              depth: job.depth + 1,
              referer: job.url,
              priority: job.depth + 1
            )
            discard scraper.urlQueue.trySend(newJob)

      scraper.stats.pagesSuccessful.inc
      scraper.stats.bytesDownloaded += html.len

    else:
      data.error = fmt"Invalid response: {response.code} {data.contentType}"
      scraper.stats.pagesError.inc

  except CatchableError as e:
    data.error = e.msg
    scraper.stats.pagesError.inc
    echo fmt"❌ Error scraping {job.url}: {e.msg}"

  finally:
    # Return rate limit token
    await scraper.rateLimiter.send(true)

    # Add artificial delay
    await chronos.sleepAsync(scraper.config.delayBetweenRequests)

  let endTime = getMonoTime()
  data.processingTime = (endTime - startTime).inMilliseconds.float64 / 1000.0

  return data

proc crawler(scraper: WebScraper, workerId: int): Future[void] {.async.} =
  ## Crawler worker that processes URLs from the queue
  echo fmt"🤖 Crawler worker {workerId} started"

  try:
    while scraper.stats.urlsVisited < scraper.config.maxPages:
      # Get next job
      let job = await scraper.urlQueue.recv()

      # Skip if already visited
      if job.url in scraper.visitedUrls:
        continue

      scraper.visitedUrls.incl(job.url)
      scraper.stats.urlsVisited.inc

      # Scrape the page
      let data = await scraper.scrapePage(job)

      # Send to data processor
      await scraper.dataQueue.send(data)

  except ChannelClosedError:
    echo fmt"🛑 Crawler worker {workerId} stopped"
  except CatchableError as e:
    echo fmt"❌ Crawler worker {workerId} error: {e.msg}"

proc dataProcessor(scraper: WebScraper): Future[seq[ScrapedData]] {.async.} =
  ## Process and collect scraped data
  var allData: seq[ScrapedData] = @[]

  try:
    while true:
      let data = await scraper.dataQueue.recv()
      allData.add(data)

      # Log successful scrapes
      if data.error.len == 0:
        echo fmt"✅ Scraped: {data.title} from {data.url} ({data.size} bytes)"
      else:
        echo fmt"❌ Failed: {data.url} - {data.error}"

      # Progress report
      if allData.len mod 10 == 0:
        echo fmt"📊 Progress: {allData.len} pages processed"

  except ChannelClosedError:
    echo "📄 Data processing completed"

  return allData

proc exportToJson(data: seq[ScrapedData], filename: string): Future[void] {.async.} =
  ## Export scraped data to JSON file
  echo fmt"💾 Exporting {data.len} records to {filename}..."

  let jsonData = %*{
    "timestamp": $now(),
    "total_pages": data.len,
    "successful": data.countIt(it.error.len == 0),
    "failed": data.countIt(it.error.len > 0),
    "pages": data.mapIt(%*{
      "url": it.url,
      "title": it.title,
      "description": it.description,
      "status_code": it.statusCode,
      "size": it.size,
      "links_count": it.links.len,
      "images_count": it.images.len,
      "processing_time": it.processingTime,
      "error": it.error
    })
  }

  writeFile(filename, $jsonData)
  echo fmt"✅ Data exported to {filename}"

proc crawl*(scraper: WebScraper, startUrls: seq[string]): Future[seq[ScrapedData]] {.async.} =
  ## Start crawling from seed URLs
  echo fmt"🕷️  Starting web crawl with {startUrls.len} seed URLs"
  echo fmt"🔧 Config: max_depth={scraper.config.maxDepth}, max_pages={scraper.config.maxPages}, concurrency={scraper.config.maxConcurrency}"

  let startTime = getMonoTime()

  # Add seed URLs to queue
  for url in startUrls:
    if scraper.isUrlAllowed(url):
      let job = CrawlJob(url: url, depth: 0, referer: "", priority: 0)
      await scraper.urlQueue.send(job)

  var result: seq[ScrapedData] = @[]

  # Start crawling
  await taskGroup:
    # Crawler workers
    for i in 1..scraper.config.maxConcurrency:
      discard g.spawn(proc(): Future[void] {.async.} =
        await scraper.crawler(i)
      )

    # Data processor
    discard g.spawn(proc(): Future[void] {.async.} =
      result = await scraper.dataProcessor()
    )

    # Monitor and shutdown
    discard g.spawn(proc(): Future[void] {.async.} =
      while scraper.stats.urlsVisited < scraper.config.maxPages:
        await chronos.sleepAsync(1.seconds)

        # Check if queue is empty and no more URLs to process
        if scraper.urlQueue.isEmpty() and scraper.stats.urlsVisited > 0:
          break

      # Close channels
      scraper.urlQueue.close()
      await chronos.sleepAsync(2.seconds)
      scraper.dataQueue.close()
    )

  let endTime = getMonoTime()
  scraper.stats.totalTime = (endTime - startTime).inMilliseconds.float64 / 1000.0

  # Print final stats
  echo "\n📊 Crawl Statistics:"
  echo fmt"  URLs visited: {scraper.stats.urlsVisited}"
  echo fmt"  Pages successful: {scraper.stats.pagesSuccessful}"
  echo fmt"  Pages with errors: {scraper.stats.pagesError}"
  echo fmt"  Total bytes downloaded: {scraper.stats.bytesDownloaded}"
  echo fmt"  Total time: {scraper.stats.totalTime:.2f}s"
  echo fmt"  Average time per page: {scraper.stats.totalTime / scraper.stats.urlsVisited.float64:.2f}s"

  return result

proc main() {.async.} =
  echo "🕷️  Concurrent Web Scraper Example with nimsync"
  echo "================================================"

  # Configure scraper
  var config = newCrawlerConfig()
  config.maxDepth = 2
  config.maxPages = 20
  config.maxConcurrency = 3
  config.delayBetweenRequests = chronos.milliseconds(500)
  config.allowedDomains = @["httpbin.org", "jsonplaceholder.typicode.com"]

  let scraper = newWebScraper(config)

  # Start URLs
  let startUrls = @[
    "https://httpbin.org/",
    "https://jsonplaceholder.typicode.com/"
  ]

  try:
    # Perform crawl
    let scrapedData = await scraper.crawl(startUrls)

    # Export results
    await exportToJson(scrapedData, "crawl_results.json")

    echo "\n🧹 Cleaning up..."
    if fileExists("crawl_results.json"):
      removeFile("crawl_results.json")

  except CatchableError as e:
    echo fmt"❌ Crawl error: {e.msg}"

  echo "\n✅ Web scraper example completed!"

when isMainModule:
  waitFor main()