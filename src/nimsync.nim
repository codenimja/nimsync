## nimsync v1.1.0 - Lock-free channels for Nim
##
## Production-ready: SPSC and MPSC channels
## Verified performance: 558M ops/sec (SPSC), 15M ops/sec (MPSC, 2 producers)
##
## Benchmark:
## nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc_simple.nim
## ./tests/performance/benchmark_spsc_simple

import private/channel_spsc
import nimsync/channels
import ../VERSION

# SPSC + MPSC Channels (production-ready, verified 558M ops/sec SPSC, 15M ops/sec MPSC)
export channel_spsc.newChannel, channel_spsc.trySend, channel_spsc.tryReceive,
    channel_spsc.ChannelMode, channel_spsc.capacity, channel_spsc.isEmpty,
    channel_spsc.isFull
export channels.send, channels.recv

# Version
export VERSION.version

# NOTE: TaskGroup, Actors, Streams, Scheduler, etc. are experimental and NOT exported.
# They live in nimsync/experimental/ — no stability guarantees.
# Preferred:  import nimsync/experimental/group
# Legacy shim (still works): import nimsync/group
