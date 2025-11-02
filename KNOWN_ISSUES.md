# Known Issues

This document tracks known bugs and limitations in nimsync v0.2.1.

## Production Code (SPSC Channels)

### No close() Method
**Status**: By design (not a bug)
**Workaround**: Use sentinel values for shutdown signaling

### Async send/recv Use Polling (IMPROVED)
**Status**: IMPROVED - Now uses exponential backoff (1ms → 100ms)
**Previous Issue**: Used fixed 1ms polling
**Current Implementation**: Exponential backoff (1ms, 2ms, 4ms, ..., up to 100ms cap)
**Impact**: Initial operations have 1ms latency, but reduces CPU usage for longer waits
**Workaround**: Use `trySend`/`tryReceive` for zero-latency operations
**Future**: Could be replaced with event-driven Chronos futures

### Size Rounded to Power of 2
**Status**: By design (performance optimization)
**Example**: `newChannel[int](10, SPSC)` creates 16-slot channel

## Experimental Code (NOT Exported)

### TaskGroup - Nested Async Macro Bug
**Status**: BROKEN - Does not compile
**Location**: `src/nimsync/group.nim:172`
**Error**: `expression has no type (or is ambiguous)`
**Cause**: Nested async macros in `spawn()` implementation
**Impact**: TaskGroup cannot be used at all
**Priority**: HIGH - Blocks v0.3.0 release

### Actors - Won't Compile
**Status**: BROKEN - Depends on unimplemented MPSC
**Location**: `src/nimsync/actors.nim:258`
**Error**: Type mismatch in mailbox.receive()
**Cause**: Uses MPSC channels which don't exist
**Dependencies**: Requires MPSC implementation first
**Priority**: MEDIUM - v0.4.0 feature

### Streams - Completely Untested
**Status**: UNKNOWN - Compiles but zero tests
**Location**: `src/nimsync/streams.nim`
**Issues**:
- Line 334: "Unbounded policy not implemented" raises exception
- Zero test coverage
**Priority**: MEDIUM - Needs testing before v0.5.0

### Scheduler - Not Actually a Scheduler
**Status**: FAKE - Just metrics tracking
**Location**: `src/nimsync/scheduler.nim`
**Missing**:
- No work queues
- No worker threads
- No task stealing logic
**Priority**: LOW - Rewrite or remove

### NUMA - Broken Node Detection
**Status**: BROKEN - Always returns 0
**Location**: `src/nimsync/numa.nim:122-136`
**Issue**: `sched_getcpu()` call commented out
**Impact**: All NUMA "optimizations" disabled
**Priority**: LOW - Fix or remove

### Cancellation - Untested in Production
**Status**: UNKNOWN - Code looks good, unproven
**Location**: `src/nimsync/cancel.nim`
**Issue**: No real-world testing
**Priority**: MEDIUM - Needs validation before export

### Supervision - Disconnected
**Status**: INCOMPLETE - Not integrated with actors
**Location**: `src/nimsync/supervision.nim`
**Missing**: Actor integration, restart logic, tests
**Priority**: LOW - Depends on working actor system

## Not Bugs (By Design)

These are intentional design decisions, not bugs:

1. **SPSC Only**: Only Single Producer Single Consumer implemented
   - MPSC/SPMC/MPMC not available (will raise ValueError)
   - This is documented and intentional for v0.2.0

2. **Internal Code Not Exported**: Experimental features not in public API
   - TaskGroup, Actors, Streams, etc. exist but not exported
   - Users can import directly: `import nimsync/group`
   - This is intentional until features are production-ready

3. **Version 0.2.0**: Not 1.0.0
   - Downgraded from premature 1.0.0 release
   - Honest versioning reflecting actual state

## Reporting Issues

Found a bug not listed here? Please report it:

**For SPSC Channels** (production code):
- Check if it's already in "Production Code" section above
- If new, open issue: https://github.com/codenimja/nimsync/issues
- Include: Nim version, OS, minimal reproduction

**For Experimental Features** (internal code):
- These are known to be incomplete/broken
- Check "Experimental Code" section first
- Feature requests welcome, but expectations should be low

## Version History

- **v0.2.1** (2025-11-01): Fixed async channels, added exponential backoff
- **v0.2.0** (2025-11-01): Reality check release, SPSC only
- **v1.0.0** (RETRACTED): Premature, claimed features that didn't work

## Contributing

Want to fix any of these? Contributions welcome!

Priority order for fixes:
1. TaskGroup nested async bug (blocking v0.3.0)
2. MPSC channel implementation (enables actors)
3. Stream testing (validation needed)
4. Scheduler/NUMA (rewrite or remove)
