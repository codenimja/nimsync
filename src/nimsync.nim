## nimsync v0.2.1 - Lock-free SPSC channels for Nim
##
## Production-ready: SPSC channels only
## Verified performance: 212,465,682 ops/sec
##
## Benchmark:
## nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim
## ./tests/performance/benchmark_spsc

import private/channel_spsc
import nimsync/channels
import ../VERSION

# SPSC Channels (production-ready, verified 212M+ ops/sec)
export channel_spsc.newChannel, channel_spsc.trySend, channel_spsc.tryReceive,
    channel_spsc.ChannelMode, channel_spsc.capacity, channel_spsc.isEmpty,
    channel_spsc.isFull
export channels.send, channels.recv

# Version
export VERSION.version

# NOTE: TaskGroup, Cancellation, Actors, Streams, etc. exist as internal modules
# but are NOT exported because they're experimental/broken. See STATUS.md for details.
# Import them directly at your own risk: import nimsync/group, nimsync/cancel, etc.
