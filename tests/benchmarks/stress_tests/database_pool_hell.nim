# database_pool_hell.nim
import nimsync, std/[random, times, strformat, asyncdispatch]

type
  DbConnection = ref object
    id: int
    inUse: bool

  DbPool = ref object
    connections: seq[DbConnection]
    available: Channel[DbConnection]
    returned: Channel[DbConnection]

proc newDbPool(size: int): DbPool =
  result = DbPool()
  result.available = newChannel[DbConnection](size, ChannelMode.SPSC)
  result.returned = newChannel[DbConnection](size, ChannelMode.SPSC)
  for i in 0..<size:
    let conn = DbConnection(id: i, inUse: false)
    result.connections.add(conn)
    discard result.available.trySend(conn)

proc acquire(pool: DbPool): Future[DbConnection] {.async.} =
  while true:
    var conn: DbConnection
    if pool.available.tryReceive(conn):
      conn.inUse = true
      return conn
    else:
      echo &"⚠️ DB POOL EXHAUSTED - connection {rand(1000)} waiting..."
      await sleepAsync(1)

proc release(pool: DbPool, conn: DbConnection) {.async.} =
  conn.inUse = false
  discard pool.returned.trySend(conn)

proc simulate_query(conn: DbConnection): Future[void] {.async.} =
  await sleepAsync(5 + rand(45))  # 5-50ms query
  if rand(100) < 2:
    raise newException(IOError, &"DB timeout on conn {conn.id}")

proc database_chaos_test() {.async.} =
  echo "🗡️ DATABASE CONNECTION POOL HELL"
  let pool = newDbPool(8)  # Only 8 connections

  var tasks = newSeq[Future[void]]()
  for i in 0..<5000:
    tasks.add(async():
      let conn = await pool.acquire()
      try:
        await simulate_query(conn)
      except:
        echo &"Query failed on conn {conn.id}"
      finally:
        await pool.release(conn)
    )

  await all(tasks)
  echo "✅ Survived DB pool starvation"

when isMainModule:
  waitFor database_chaos_test()