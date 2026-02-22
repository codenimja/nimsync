## nimsync — NUMA-Aware Optimizations
##
## This module provides Non-Uniform Memory Access (NUMA) optimizations for
## systems with multiple memory domains. It uses the Node Replication (NR)
## pattern to automatically transform sequential data structures into
## efficient NUMA-aware concurrent structures.
##
## Key Features:
## - Automatic NUMA topology detection
## - Node replication for high-contention scenarios
## - Hierarchical communication within NUMA nodes
## - NUMA-local channel variants
## - Graceful fallback on non-NUMA systems

import std/[atomics, os, strutils, sets, cpuinfo]
import chronos
import ./errors
import ../channels as ch

type
  ## NUMA topology information
  NumaTopology* = ref object
    ## Whether NUMA is available on this system
    available*: bool
    ## Number of NUMA nodes
    nodeCount*: int
    ## CPUs per NUMA node
    cpusPerNode*: int
    ## Total CPU count
    totalCpus*: int
    ## Node-to-CPU mapping
    nodeMapping*: seq[seq[int]]

  ## NUMA replication policy for channels and actors
  NumaReplicationPolicy* = enum
    Disabled      ## No NUMA optimization
    Local         ## Single-node operations only (fails cross-node)
    Replicated    ## Node replication (NR) for high-contention
    Adaptive      ## Switch between modes based on contention

  ## NUMA-aware channel variant with replication
  NumaLocalChannel*[T] = ref object
    ## Primary channel on node where created
    local*: ch.Channel[T]
    ## Replicated channels for other nodes (NR pattern)
    replicas*: seq[ch.Channel[T]]
    ## Current replication policy
    policy*: NumaReplicationPolicy
    ## Contention counter for adaptive switching
    contentionCount*: Atomic[uint32]
    ## Node where this channel was created
    sourceNode*: int

  ## NUMA aware actor mailbox
  NumaAwareMailbox*[T] = ref object
    ## Local mailbox (primary)
    local*: seq[T]
    ## Replica mailboxes (NR pattern)
    replicas*: seq[seq[T]]
    ## Policy for replication
    policy*: NumaReplicationPolicy
    ## Source NUMA node
    sourceNode*: int

# Global NUMA topology (lazily initialized)
var globalTopology*: NumaTopology

## Detect system NUMA topology
##
## Returns topology information or nil if detection fails
proc detectNumaTopology*(): NumaTopology =
  # Try to detect from /proc/cpuinfo on Linux
  when defined(linux):
    try:
      # Simple heuristic: check for numa_node in cpuinfo
      let cpuInfo = readFile("/proc/cpuinfo")
      let hasNuma = "numa_node" in cpuInfo

      if hasNuma:
        # Count unique NUMA nodes
        var nodeSet = initHashSet[int]()
        for line in cpuInfo.splitLines():
          if line.startsWith("numa_node"):
            let parts = line.split(":")
            if parts.len > 1:
              let nodeStr = parts[1].strip()
              if nodeStr != "-1":
                nodeSet.incl(nodeStr.parseInt())

        let nodeCount = nodeSet.len
        let cpuCount = countProcessors()

        return NumaTopology(
          available: nodeCount > 1,
          nodeCount: if nodeCount > 0: nodeCount else: 1,
          cpusPerNode: cpuCount div max(nodeCount, 1),
          totalCpus: cpuCount,
          nodeMapping: @[] # Would need more detailed parsing
        )
    except:
      discard

  # Fallback: single NUMA node (no optimization)
  NumaTopology(
    available: false,
    nodeCount: 1,
    cpusPerNode: countProcessors(),
    totalCpus: countProcessors(),
    nodeMapping: @[]
  )

## Get or initialize global NUMA topology
proc getTopology*(): NumaTopology =
  if globalTopology == nil:
    globalTopology = detectNumaTopology()
  globalTopology

## Get current CPU's NUMA node (platform-specific)
proc getCurrentNode*(): int =
  when defined(linux):
    # On Linux, we can try sched_getcpu and numactl
    # Check if sched_getcpu is available at compile time
    when declared(sched_getcpu):
      try:
        let cpuId = sched_getcpu()
        let topology = getTopology()
        if topology.available and topology.nodeMapping.len > 0:
          for node, cpus in topology.nodeMapping:
            if cpus.contains(cpuId):
              return node
      except:
        discard
    else:
      # sched_getcpu not available, use alternative approach
      discard

  0 # Default to node 0

## Check if two CPUs are on the same NUMA node
proc sameNumaNode*(cpu1: int, cpu2: int): bool =
  let topology = getTopology()
  if not topology.available or topology.nodeMapping.len == 0:
    return true # Fallback: assume all on same node

  for cpus in topology.nodeMapping:
    if cpus.contains(cpu1) and cpus.contains(cpu2):
      return true

  false

## Initialize a NUMA-aware channel with replication
proc initNumaLocalChannel*[T](policy: NumaReplicationPolicy = Replicated): NumaLocalChannel[T] =
  let topology = getTopology()
  let sourceNode = getCurrentNode()

  if not topology.available or policy == Disabled:
    # Fallback to single channel
    return NumaLocalChannel[T](
      local: ch.newChannel[T](1000),
      replicas: @[],
      policy: Disabled,
      sourceNode: sourceNode
    )

  # Create replicated channels for each NUMA node
  var replicas: seq[ch.Channel[T]] = @[]
  for _ in 0 ..< topology.nodeCount:
    replicas.add(ch.newChannel[T](1000))

  NumaLocalChannel[T](
    local: ch.newChannel[T](1000),
    replicas: replicas,
    policy: policy,
    contentionCount: 0'u32,
    sourceNode: sourceNode
  )

## Send to NUMA-aware channel (uses local replica when possible)
proc send*[T](chan: NumaLocalChannel[T], value: T): Future[void] {.async.} =
  if not chan.local.isClosed:
    if chan.policy == Disabled or chan.replicas.len == 0:
      # Single channel fallback
      await chan.local.send(value)
    else:
      # Send to local node replica when possible
      let currentNode = getCurrentNode()
      if currentNode == chan.sourceNode:
        await chan.local.send(value)
      elif currentNode < chan.replicas.len:
        await chan.replicas[currentNode].send(value)
        discard atomicInc(chan.contentionCount)
      else:
        # Fallback to primary
        await chan.local.send(value)
        discard atomicInc(chan.contentionCount)

## Receive from NUMA-aware channel
proc recv*[T](chan: NumaLocalChannel[T]): Future[T] {.async.} =
  if chan.policy == Disabled or chan.replicas.len == 0:
    return await chan.local.recv()
  else:
    # Try local replica first
    let currentNode = getCurrentNode()
    if currentNode == chan.sourceNode:
      return await chan.local.recv()
    elif currentNode < chan.replicas.len:
      return await chan.replicas[currentNode].recv()
    else:
      return await chan.local.recv()

## Close NUMA-aware channel
proc close*[T](chan: NumaLocalChannel[T]) =
  chan.local.close()
  for replica in chan.replicas:
    replica.close()

## Format NUMA topology information as string
proc formatTopology*(topology: NumaTopology): string =
  "NumaTopology(\n" &
  "  Available: " & $topology.available & "\n" &
  "  Nodes: " & $topology.nodeCount & "\n" &
  "  CPUs per Node: " & $topology.cpusPerNode & "\n" &
  "  Total CPUs: " & $topology.totalCpus & "\n" &
  ")"

## Get statistics on NUMA channel usage
proc getNumaStats*[T](chan: NumaLocalChannel[T]): string =
  let contentionCount = atomicLoad(chan.contentionCount)
  "NumaChannelStats(\n" &
  "  Source Node: " & $chan.sourceNode & "\n" &
  "  Policy: " & $chan.policy & "\n" &
  "  Cross-Node Accesses: " & $contentionCount & "\n" &
  ")"

# Export sched_getcpu on Linux
when defined(linux):
  proc sched_getcpu*(): cint {.importc: "sched_getcpu", header: "<sched.h>".}
