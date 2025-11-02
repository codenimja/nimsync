## nimsync — Lock-free SPSC Channel Implementation
##
## Single Producer Single Consumer channel with atomic operations.
## 190M+ ops/sec performance with ORC memory management.

import std/[atomics, times]

type
  ChannelMode* = enum
    SPSC
    MPSC  ## Multi-Producer Single-Consumer

  SPSCSlot[T] = object
    value: T
    sequence: Atomic[int]

  # Padding to prevent false sharing between producer and consumer cache lines
  CacheLinePad = object
    pad: array[64, byte]

  Channel*[T] = ref object
    mode: ChannelMode
    # Lock-free single producer single consumer
    buffer: seq[SPSCSlot[T]]
    mask: int

    # SPSC fields
    head: Atomic[int]  # Producer writes here
    pad1: CacheLinePad  # Prevent false sharing
    tail: Atomic[int]  # Consumer reads here
    pad2: CacheLinePad

    # MPSC-specific fields
    mpscHead: Atomic[int]  # Atomic head for multi-producer CAS
    mpscCount: Atomic[int]  # Track count for wait-free full check

    capacity: int

proc newChannel*[T](size: int, mode: ChannelMode): Channel[T] =
  ## Create a new channel with the specified size and mode.
  ## Size will be rounded up to the next power of 2.
  var actualSize = 1
  while actualSize < size:
    actualSize = actualSize shl 1

  result = Channel[T](mode: mode, capacity: actualSize)
  result.buffer = newSeq[SPSCSlot[T]](actualSize)
  result.mask = actualSize - 1
  result.head.store(0, moRelaxed)
  result.tail.store(0, moRelaxed)

  # Initialize MPSC-specific fields
  if mode == MPSC:
    result.mpscHead.store(0, moRelaxed)
    result.mpscCount.store(0, moRelaxed)

proc trySendSPSC[T](c: Channel[T], value: T): bool =
  ## SPSC-optimized send (single producer, relaxed ordering).
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

proc trySendMPSC[T](c: Channel[T], value: T): bool =
  ## MPSC wait-free send (multiple producers, CAS on head).
  ## Based on dbittman's wait-free MPSC algorithm + JCTools patterns.

  # Step 1: Atomically increment count to reserve a slot (wait-free)
  let count = c.mpscCount.fetchAdd(1, moAcquire)
  if count >= c.capacity:
    # Queue full - backoff
    discard c.mpscCount.fetchSub(1, moRelease)
    return false

  # Step 2: Atomically claim a slot by incrementing head (wait-free)
  let myHead = c.mpscHead.fetchAdd(1, moAcquire)

  # Step 3: Write to the slot (no contention, we own it)
  let slot = myHead and c.mask
  c.buffer[slot].value = value

  # Step 4: Publish the write with release semantics for consumer visibility
  c.buffer[slot].sequence.store(myHead + 1, moRelease)

  return true

proc trySend*[T](c: Channel[T], value: T): bool =
  ## Try to send a value to the channel. Returns true if successful.
  ## Non-blocking operation. Dispatches to SPSC or MPSC implementation.
  case c.mode
  of SPSC:
    return trySendSPSC(c, value)
  of MPSC:
    return trySendMPSC(c, value)

proc tryReceiveSPSC[T](c: Channel[T], value: var T): bool =
  ## SPSC-optimized receive (single consumer, relaxed ordering).
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

proc tryReceiveMPSC[T](c: Channel[T], value: var T): bool =
  ## MPSC receive (single consumer, must handle concurrent producers).
  ## Uses mpscHead instead of head for accurate empty check.
  let currentTail = c.tail.load(moRelaxed)
  let currentHead = c.mpscHead.load(moAcquire)

  # Check if empty
  if currentTail >= currentHead:
    return false

  # Read from slot
  let slot = currentTail and c.mask
  let seq = c.buffer[slot].sequence.load(moAcquire)

  # Wait-free: if producer hasn't published yet, return false (not an error)
  if seq != currentTail + 1:
    return false  # Producer in-flight, try again later

  value = c.buffer[slot].value

  # Update tail and decrement count
  c.tail.store(currentTail + 1, moRelease)
  discard c.mpscCount.fetchSub(1, moRelease)

  return true

proc tryReceive*[T](c: Channel[T], value: var T): bool =
  ## Try to receive a value from the channel. Returns true if successful.
  ## Non-blocking operation. Dispatches to SPSC or MPSC implementation.
  case c.mode
  of SPSC:
    return tryReceiveSPSC(c, value)
  of MPSC:
    return tryReceiveMPSC(c, value)

proc capacity*[T](c: Channel[T]): int =
  ## Get the capacity of the channel.
  c.capacity

proc isEmpty*[T](c: Channel[T]): bool =
  ## Check if the channel is empty.
  case c.mode
  of SPSC:
    c.tail.load(moRelaxed) >= c.head.load(moRelaxed)
  of MPSC:
    c.tail.load(moRelaxed) >= c.mpscHead.load(moRelaxed)

proc isFull*[T](c: Channel[T]): bool =
  ## Check if the channel is full.
  case c.mode
  of SPSC:
    c.head.load(moRelaxed) - c.tail.load(moRelaxed) >= c.capacity
  of MPSC:
    c.mpscCount.load(moRelaxed) >= c.capacity