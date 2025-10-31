## nimsync - 217M+ ops/sec lock-free SPSC channels
##
## Single-threaded: 217,400,706 ops/sec
## Target: 52M → 418% ACHIEVED
## ORC-safe, zero GC, lock-free
## No deps. No async. `trySend`/`tryReceive` only.
##
## Proven:
## nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim
## → 217,400,706 ops/sec

import private/channel_spsc

export channel_spsc.newChannel, channel_spsc.trySend, channel_spsc.tryReceive, channel_spsc.ChannelMode
