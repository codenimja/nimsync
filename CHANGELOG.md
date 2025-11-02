# Changelog

## [0.2.1] - 2025-11-01

### Fixed
- **Async channels now actually work** - Previous implementation was completely broken
  - Fixed `send()`/`recv()` to use actual SPSC implementation (was referencing non-existent fields)
  - Removed duplicate Channel/ChannelMode type definitions
  - Added exponential backoff (1ms → 100ms) to reduce CPU usage
  - Fixed Chronos deprecation warnings
- **Deduplicated channels.nim** - Removed 100+ lines of duplicate code
  - Now properly imports from channel_spsc instead of reimplementing everything

### Added
- Comprehensive async channel tests (tests/unit/test_async_channel.nim)
- Added async tests to CI workflow

### Changed
- Updated KNOWN_ISSUES.md to reflect async improvements

## [0.2.0] - 2025-11-01

### Reality Check Release
Downgraded from v1.0.0 to v0.2.0 to accurately reflect what's production-ready.

### Production-Ready
- **SPSC Channels**: 212M+ ops/sec verified
  - Tests passing: tests/unit/test_channel.nim
  - Benchmark verified: tests/performance/benchmark_spsc.nim

### Removed from Public API
- TaskGroup (has bugs, removed from exports)
- Cancellation (untested, removed from exports)
- All other features remain internal/experimental

### Changed
- Version: 1.0.0 → 0.2.0
- README.md: Replaced with honest version
- Build: "production" → "experimental"

### Added
- STATUS.md: Feature audit
- CI workflow: Test + benchmark validation
- CHANGELOG.md: This file
- KNOWN_ISSUES.md: Documented bugs and limitations

### Known Issues
- Async send/recv use polling (exponential backoff)
- TaskGroup: nested async macro bugs (not exported)
- Actors: won't compile, needs MPSC
- Streams: compiles but untested
- Scheduler: fake (just metrics)
- NUMA: broken node detection

See KNOWN_ISSUES.md for complete list.

## [1.0.0] - RETRACTED
Premature release. Use v0.2.0 instead.

Retracted because:
- Claimed features that don't work
- TaskGroup exported but broken
- Examples showed inaccessible API
- No CI validation
