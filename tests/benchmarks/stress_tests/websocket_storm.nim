# websocket_storm.nim
import std/[strformat, random, json, times, asyncdispatch, strutils]

proc websocket_client_sim(id: int) {.async.} =
  var msg_count = 0
  while msg_count < 1000:
    # Send burst
    for _ in 0..<10:
      let msg = %* {"client": id, "ts": epochTime(), "data": repeat("x", 1024)}
      # Simulate send
      await sleepAsync(0)  # yield
    msg_count += 10
    await sleepAsync(rand(5))  # bursty

  # Simulate disconnect
  if rand(10) == 0:
    raise newException(CatchableError, &"Client {id} crashed")

proc websocket_flood_test() {.async.} =
  echo "🌪️ WEBSOCKET MESSAGE STORM: 1000 clients"
  var clients = newSeq[Future[void]]()
  for i in 0..<1000:
    clients.add(websocket_client_sim(i))
  await all(clients)
  echo "🌟 WebSocket flood survived"

when isMainModule:
  waitFor websocket_flood_test()