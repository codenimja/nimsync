## Actors with Supervision Example
##
## Demonstrates the planned actor system with bounded mailboxes,
## backpressure, supervision policies, and failure recovery.
##
## This example shows how nimsync will provide lightweight actors
## with proper error handling and supervision.

import std/[times, strformat, random]
import chronos
import nimsync/[channels, group, cancel]

type
  # Message types for actor communication
  ActorMessage = object
    case kind: ActorMessageKind
    of amkPing:
      pingId: int
      sender: string
    of amkPong:
      pongId: int
      responseTime: float
    of amkWork:
      workId: int
      data: string
    of amkResult:
      resultId: int
      result: string
    of amkStop:
      discard

  ActorMessageKind = enum
    amkPing, amkPong, amkWork, amkResult, amkStop

  # Actor reference (placeholder for real ActorRef[T])
  MockActorRef = object
    name: string
    mailbox: Channel[ActorMessage]
    isRunning: bool

  # Supervision policies
  SupervisionPolicy = enum
    spRestart,      # Restart failed actor
    spEscalate,     # Escalate to parent supervisor
    spIgnore        # Ignore failures

  ActorStats = object
    messagesReceived: int
    messagesProcessed: int
    errors: int
    restarts: int

proc newMockActor(name: string, mailboxCapacity: int = 100): MockActorRef =
  MockActorRef(
    name: name,
    mailbox: newChannel[ActorMessage](capacity = mailboxCapacity),
    isRunning: false
  )

proc send(actor: var MockActorRef, message: ActorMessage): Future[bool] {.async.} =
  ## Send message to actor (with backpressure simulation)
  if not actor.isRunning:
    echo fmt"Actor {actor.name} is not running, message dropped"
    return false

  # In real implementation, this would respect mailbox capacity and backpressure
  # For now, simulate potential backpressure
  if actor.mailbox.capacity > 0:  # Bounded mailbox
    # Simulate full mailbox occasionally
    if rand(1.0) < 0.1:  # 10% chance of temporary backpressure
      echo fmt"Mailbox backpressure for {actor.name}, waiting..."
      await sleepAsync(50.milliseconds)

  actor.mailbox.send(message)
  return true

proc receive(actor: var MockActorRef): Future[Option[ActorMessage]] {.async.} =
  ## Receive message from actor mailbox
  var msg: ActorMessage
  if actor.mailbox.tryRecv(msg):
    return some(msg)
  else:
    # Simulate waiting for messages
    await sleepAsync(25.milliseconds)
    return none(ActorMessage)

proc pingPongActor(actor: var MockActorRef, partner: var MockActorRef, stats: var ActorStats) {.async.} =
  ## Simple ping-pong actor behavior
  echo fmt"Starting ping-pong actor: {actor.name}"
  actor.isRunning = true

  try:
    while actor.isRunning:
      let msgOpt = await actor.receive()

      if msgOpt.isSome():
        let msg = msgOpt.get()
        stats.messagesReceived += 1

        case msg.kind:
        of amkPing:
          echo fmt"{actor.name} received PING {msg.pingId} from {msg.sender}"
          # Send PONG back
          let pongMsg = ActorMessage(
            kind: amkPong,
            pongId: msg.pingId,
            responseTime: 0.1
          )
          if await partner.send(pongMsg):
            stats.messagesProcessed += 1

        of amkPong:
          echo fmt"{actor.name} received PONG {msg.pongId} (response time: {msg.responseTime}ms)"
          stats.messagesProcessed += 1

        of amkStop:
          echo fmt"{actor.name} received STOP signal"
          actor.isRunning = false
          break

        else:
          echo fmt"{actor.name} received unknown message type"

      # Simulate some processing time
      await sleepAsync(10.milliseconds)

  except CatchableError as e:
    echo fmt"Error in {actor.name}: {e.msg}"
    stats.errors += 1
    actor.isRunning = false

  echo fmt"{actor.name} stopped"

proc workerActor(actor: var MockActorRef, supervisor: var MockActorRef, stats: var ActorStats, failureRate: float = 0.0) {.async.} =
  ## Worker actor that processes work messages and may fail
  echo fmt"Starting worker actor: {actor.name}"
  actor.isRunning = true

  try:
    while actor.isRunning:
      let msgOpt = await actor.receive()

      if msgOpt.isSome():
        let msg = msgOpt.get()
        stats.messagesReceived += 1

        case msg.kind:
        of amkWork:
          echo fmt"{actor.name} processing work {msg.workId}: {msg.data}"

          # Simulate random failures
          if rand(1.0) < failureRate:
            raise newException(CatchableError, fmt"Simulated failure in work {msg.workId}")

          # Simulate work processing
          await sleepAsync(100.milliseconds)

          # Send result back to supervisor
          let resultMsg = ActorMessage(
            kind: amkResult,
            resultId: msg.workId,
            result: fmt"Processed: {msg.data}"
          )
          if await supervisor.send(resultMsg):
            stats.messagesProcessed += 1

        of amkStop:
          echo fmt"{actor.name} received STOP signal"
          actor.isRunning = false
          break

        else:
          echo fmt"{actor.name} received unknown message type"

      await sleepAsync(10.milliseconds)

  except CatchableError as e:
    echo fmt"Error in {actor.name}: {e.msg}"
    stats.errors += 1
    actor.isRunning = false

  echo fmt"{actor.name} stopped"

proc supervisorActor(actor: var MockActorRef, workers: var seq[MockActorRef], policy: SupervisionPolicy, stats: var ActorStats) {.async.} =
  ## Supervisor actor that manages worker actors
  echo fmt"Starting supervisor actor: {actor.name} with policy: {policy}"
  actor.isRunning = true

  var workId = 0

  try:
    while actor.isRunning:
      let msgOpt = await actor.receive()

      if msgOpt.isSome():
        let msg = msgOpt.get()
        stats.messagesReceived += 1

        case msg.kind:
        of amkResult:
          echo fmt"Supervisor received result {msg.resultId}: {msg.result}"
          stats.messagesProcessed += 1

        of amkStop:
          echo "Supervisor received STOP signal"
          # Stop all workers
          for worker in workers.mitems:
            discard await worker.send(ActorMessage(kind: amkStop))
          actor.isRunning = false
          break

        else:
          discard

      # Generate work for workers
      if workId < 10:  # Limit for demo
        workId += 1
        let workMsg = ActorMessage(
          kind: amkWork,
          workId: workId,
          data: fmt"task-{workId}"
        )

        # Send work to a random worker
        if workers.len > 0:
          let workerIdx = rand(workers.len - 1)
          if workers[workerIdx].isRunning:
            discard await workers[workerIdx].send(workMsg)
          else:
            # Worker failed, apply supervision policy
            echo fmt"Worker {workers[workerIdx].name} has failed, applying policy: {policy}"
            case policy:
            of spRestart:
              echo fmt"Restarting worker {workers[workerIdx].name}"
              workers[workerIdx].isRunning = true
              stats.restarts += 1
              # In real implementation, would restart the actor task
            of spEscalate:
              echo "Escalating failure to parent supervisor"
              # Would escalate to parent
            of spIgnore:
              echo "Ignoring worker failure"

      await sleepAsync(200.milliseconds)

  except CatchableError as e:
    echo fmt"Error in supervisor {actor.name}: {e.msg}"
    stats.errors += 1
    actor.isRunning = false

  echo fmt"Supervisor {actor.name} stopped"

proc pingPongExample() {.async.} =
  ## Demonstrates simple ping-pong between two actors
  echo "=== Ping-Pong Actor Example ==="

  var ping = newMockActor("Ping", 10)
  var pong = newMockActor("Pong", 10)
  var pingStats = ActorStats()
  var pongStats = ActorStats()

  # Start actors
  let pingTask = pingPongActor(ping, pong, pingStats)
  let pongTask = pingPongActor(pong, ping, pongStats)

  # Send initial ping
  let initialPing = ActorMessage(
    kind: amkPing,
    pingId: 1,
    sender: "external"
  )
  discard await ping.send(initialPing)

  # Let them communicate for a bit
  await sleepAsync(1.seconds)

  # Stop actors
  discard await ping.send(ActorMessage(kind: amkStop))
  discard await pong.send(ActorMessage(kind: amkStop))

  echo fmt"Ping stats: received={pingStats.messagesReceived}, processed={pingStats.messagesProcessed}, errors={pingStats.errors}"
  echo fmt"Pong stats: received={pongStats.messagesReceived}, processed={pongStats.messagesProcessed}, errors={pongStats.errors}"

proc supervisionExample() {.async.} =
  ## Demonstrates supervision with failure recovery
  echo "\n=== Supervision Example ==="

  var supervisor = newMockActor("Supervisor", 50)
  var workers = @[
    newMockActor("Worker-1", 20),
    newMockActor("Worker-2", 20),
    newMockActor("Worker-3", 20)
  ]

  var supervisorStats = ActorStats()
  var workerStats = @[ActorStats(), ActorStats(), ActorStats()]

  # Start supervisor
  let supervisorTask = supervisorActor(supervisor, workers, spRestart, supervisorStats)

  # Start workers with different failure rates
  let workerTasks = @[
    workerActor(workers[0], supervisor, workerStats[0], 0.1),  # 10% failure rate
    workerActor(workers[1], supervisor, workerStats[1], 0.2),  # 20% failure rate
    workerActor(workers[2], supervisor, workerStats[2], 0.0)   # No failures
  ]

  # Let the system run for a while
  await sleepAsync(3.seconds)

  # Stop the supervisor (which will stop workers)
  discard await supervisor.send(ActorMessage(kind: amkStop))

  echo fmt"Supervisor stats: received={supervisorStats.messagesReceived}, processed={supervisorStats.messagesProcessed}, restarts={supervisorStats.restarts}"
  for i, stats in workerStats:
    echo fmt"Worker-{i+1} stats: received={stats.messagesReceived}, processed={stats.messagesProcessed}, errors={stats.errors}"

proc main() {.async.} =
  echo "=== Actors with Supervision Example ==="
  echo "Demonstrating planned API for lightweight actors with supervision"
  echo ""

  # Note: In the real implementation, this would use proper ActorRef[T] types:
  # let workerRef = spawnActor[WorkMessage](workerBehavior, capacity = 1024)
  # await workerRef.tell(WorkMessage(data: "process this"))

  randomize()  # For simulating failures

  await pingPongExample()
  await supervisionExample()

  echo "\nExample completed!"
  echo "\nIn the real implementation:"
  echo "- Actors would have typed mailboxes (ActorRef[MessageType])"
  echo "- Supervision would integrate with TaskGroup policies"
  echo "- Backpressure would be handled automatically by bounded mailboxes"
  echo "- Actor restarts would preserve mailbox state where appropriate"
  echo "- Memory usage would be bounded by mailbox capacity limits"

when isMainModule:
  waitFor main()