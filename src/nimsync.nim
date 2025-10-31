## nimsync - 213M+ ops/sec lock-free SPSC channels
##
## Single-threaded: 213,567,459 ops/sec
## Target: 52M → 410% ACHIEVED
## ORC-safe, zero GC, lock-free
## No deps. No async. `trySend`/`tryReceive` only.
##
## Proven:
## nim c -d:danger --opt:speed --threads:on --mm:orc tests/performance/benchmark_spsc.nim
## → 213,567,459 ops/sec

import private/channel_spsc

export channel_spsc.newChannel, channel_spsc.trySend, channel_spsc.tryReceive, channel_spsc.ChannelMode
