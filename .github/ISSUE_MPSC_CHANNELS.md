# MPSC: Multi-Producer Single-Consumer Channels

## Description
Implement production-ready MPSC (Multi-Producer Single-Consumer) channels to enable multi-threaded actor systems and parallel workloads.

## Current Status
- **Module**: `src/nimsync/channels.nim` (SPSC only)
- **MPSC**: ⚠️ Experimental / Not implemented
- **Blocking**: Actor system, parallel processing

## Why MPSC Matters
Current SPSC (Single-Producer Single-Consumer) channels work great for:
- ✅ Pipeline stages (one producer → one consumer)
- ✅ Thread-to-thread communication
- ✅ Lock-free performance (615M ops/sec)

But many real-world patterns need multiple producers:
- ❌ Multiple workers → single aggregator
- ❌ Actor mailboxes (many senders → one actor)
- ❌ Event bus patterns
- ❌ Work-stealing schedulers

## Technical Challenges
MPSC is harder than SPSC because:
1. **Contention**: Multiple producers need coordination
2. **Lock-free is complex**: CAS operations, ABA problem
3. **Performance**: Goal is <100ns P99 latency (vs SPSC's 31ns)

## Design Options

### Option 1: Lock-Based (Simplest)
```nim
type
  MPSCChannel[T] = object
    queue: Deque[T]
    lock: Lock  # Protect producer side only
    consumerHead: Atomic[int]
```
**Pros**: Easy to implement, correct by default  
**Cons**: Lock contention under high load, not truly lock-free

### Option 2: CAS-Based Lock-Free (Industry Standard)
```nim
# Based on Michael-Scott queue or similar
type
  MPSCNode[T] = object
    data: T
    next: Atomic[ptr MPSCNode[T]]
  
  MPSCChannel[T] = object
    head: Atomic[ptr MPSCNode[T]]  # Consumer only
    tail: Atomic[ptr MPSCNode[T]]  # Producers compete with CAS
```
**Pros**: Lock-free, better scaling  
**Cons**: Complex, ABA problem, memory management tricky

### Option 3: Hybrid Approach
Lock-free fast path, fallback to lock on contention

## Acceptance Criteria
- [ ] MPSC channel implementation passes all tests
- [ ] Performance benchmarks:
  - [ ] 2 producers: >400M ops/sec total throughput
  - [ ] 8 producers: >300M ops/sec total throughput
  - [ ] P99 latency <100ns
  - [ ] Contention <10% under stress
- [ ] Memory safety verified (no leaks, no use-after-free)
- [ ] Integration tests with actor system
- [ ] Documentation with examples
- [ ] Comparison benchmarks vs Go channels, Tokio mpsc

## Reference Implementations
- **Tokio MPSC**: https://github.com/tokio-rs/tokio/tree/master/tokio/src/sync/mpsc
- **Crossbeam**: https://github.com/crossbeam-rs/crossbeam/tree/master/crossbeam-channel
- **Go channels**: https://github.com/golang/go/blob/master/src/runtime/chan.go
- **Michael-Scott Queue**: Classic lock-free MPSC algorithm

## Help Wanted
**Skills needed**: Concurrent data structures, atomic operations, memory ordering, benchmarking

**Resources**:
- "The Art of Multiprocessor Programming" (Herlihy & Shavit)
- Linux kernel's `kfifo` MPMC implementation
- Chronos async internals for integration

**Mentorship**: Available - @boonzy can provide guidance on nimsync architecture and benchmarking standards

---

**Priority**: High 🔴 (enables actor system)
**Difficulty**: Very Hard 🔴🔴 (lock-free concurrency is complex)
**Impact**: Very High 🟢🟢 (unlocks entire actor ecosystem)

## Bonus: MPMC Later
After MPSC works, consider MPMC (Multi-Producer Multi-Consumer) for work-stealing schedulers. But MPSC is the critical path.
