## nimsync — High-performance Channels
##
## Lock-free SPSC channels with atomic operations
##
## **v1.0.0 Limitation**: Only SPSC (Single Producer Single Consumer) is implemented.
## MPSC, SPMC, and MPMC modes are defined but not yet functional.

import std/[atomics, times]
import chronos

type
  ChannelMode* = enum
    SPSC  ## Single Producer Single Consumer (implemented)
    MPSC  ## Multi Producer Single Consumer (NOT implemented - raises error)
    SPMC  ## Single Producer Multi Consumer (NOT implemented - raises error)
    MPMC  ## Multi Producer Multi Consumer (NOT implemented - raises error)

  SPSCSlot[T] = object
    value: T
    sequence: Atomic[int]
  
  Channel*[T] = ref object
    case mode: ChannelMode
    of SPSC:
      # Lock-free single producer single consumer
      buffer: seq[SPSCSlot[T]]
      mask: int
      head: Atomic[int]  # Producer writes here
      tail: Atomic[int]  # Consumer reads here
    else:
      # Fallback for now
      queue: seq[T]
      queueHead: int
      queueTail: int
    capacity: int

proc newChannel*[T](size: int, mode: ChannelMode): Channel[T] =
  ## Create a new channel with the specified capacity and mode.
  ## 
  ## **v1.0.0**: Only SPSC mode is implemented. Other modes will raise an error.
  
  if mode != SPSC:
    raise newException(ValueError, 
      "Only SPSC mode is implemented in v1.0.0. MPSC/SPMC/MPMC are not available.")
  
  # Round up to power of 2 for mask optimization
  var actualSize = 1
  while actualSize < size:
    actualSize = actualSize shl 1
  
  result = Channel[T](mode: mode, capacity: actualSize)
  
  case mode
  of SPSC:
    result.buffer = newSeq[SPSCSlot[T]](actualSize)
    result.mask = actualSize - 1
    result.head.store(0)
    result.tail.store(0)
  else:
    # This should never be reached due to the check above
    discard

proc send*[T](c: Channel[T], value: T): Future[void] {.async.} =
  while c.queue.len >= c.capacity:
    await sleepAsync(1)  # 1ms sleep
  c.queue.addLast(value)

proc recv*[T](c: Channel[T]): Future[T] {.async.} =
  while c.queue.len == 0:
    await sleepAsync(1)  # 1ms sleep
  result = c.queue.popFirst()

proc trySend*[T](c: Channel[T], value: T): bool =
  case c.mode
  of SPSC:
    let currentHead = c.head.load(moRelaxed)
    let currentTail = c.tail.load(moAcquire)
    
    # Check if full
    if currentHead - currentTail >= c.capacity:
      return false
    
    # Write to slot
    let slot = currentHead and c.mask
    c.buffer[slot].value = value
    c.buffer[slot].sequence.store(currentHead + 1, moRelease)
    
    # Update head
    c.head.store(currentHead + 1, moRelease)
    return true
  else:
    # Simple queue fallback
    if c.queueHead - c.queueTail >= c.capacity:
      return false
    c.queue[c.queueHead and (c.capacity - 1)] = value
    inc c.queueHead
    return true

proc tryReceive*[T](c: Channel[T], value: var T): bool =
  case c.mode
  of SPSC:
    let currentTail = c.tail.load(moRelaxed)
    let currentHead = c.head.load(moAcquire)
    
    # Check if empty
    if currentTail >= currentHead:
      return false
    
    # Read from slot
    let slot = currentTail and c.mask
    let seq = c.buffer[slot].sequence.load(moAcquire)
    
    if seq != currentTail + 1:
      return false  # Not ready yet
      
    value = c.buffer[slot].value
    
    # Update tail
    c.tail.store(currentTail + 1, moRelease)
    return true
  else:
    # Simple queue fallback
    if c.queueTail >= c.queueHead:
      return false
    value = c.queue[c.queueTail and (c.capacity - 1)]
    inc c.queueTail
    return true

proc capacity*[T](c: Channel[T]): int = c.capacity

proc isEmpty*[T](c: Channel[T]): bool = 
  case c.mode
  of SPSC:
    c.tail.load(moRelaxed) >= c.head.load(moRelaxed)
  else:
    c.queueTail >= c.queueHead

proc isFull*[T](c: Channel[T]): bool = 
  case c.mode
  of SPSC:
    c.head.load(moRelaxed) - c.tail.load(moRelaxed) >= c.capacity
  else:
    c.queueHead - c.queueTail >= c.capacity