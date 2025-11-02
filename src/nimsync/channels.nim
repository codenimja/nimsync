## nimsync — High-performance Channels
##
## Async wrappers for SPSC channels
##
## Provides async send/recv wrappers around the lock-free SPSC implementation

import chronos
import ../private/channel_spsc

export channel_spsc.Channel, channel_spsc.ChannelMode

proc send*[T](c: channel_spsc.Channel[T], value: T): Future[void] {.async.} =
  ## Async send - waits until channel has space
  ## Uses exponential backoff to reduce CPU usage
  var backoff = 1  # Start with 1ms
  while true:
    if channel_spsc.trySend(c, value):
      return
    await sleepAsync(backoff)
    backoff = min(backoff * 2, 100)  # Cap at 100ms

proc recv*[T](c: channel_spsc.Channel[T]): Future[T] {.async.} =
  ## Async receive - waits until value available
  ## Uses exponential backoff to reduce CPU usage
  var value: T
  var backoff = 1  # Start with 1ms
  while true:
    if channel_spsc.tryReceive(c, value):
      return value
    await sleepAsync(backoff)
    backoff = min(backoff * 2, 100)  # Cap at 100ms