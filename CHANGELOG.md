# Changelog

All notable changes to nimsync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-02-22

### Changed
- Moved 10 experimental modules (actors, streams, group, etc.) to `src/nimsync/experimental/`
- Backward-compatible shims kept at old paths — existing imports unchanged
- Moved `BENCHMARKS.md` to `docs/`
- `nimble bench` now points to `tests/performance/run_all_benchmarks.sh`

### Fixed
- Version inconsistency: `VERSION.nim` and `nimsync.nimble` now both reflect v1.1.0
- Committed ELF binaries removed from git history (17 test/example binaries)
- Stale benchmark scripts in `scripts/` removed (referenced deprecated `benchmarks/` dir)
- Duplicate `docs/LICENSE` removed
- Accidentally committed benchmark CSV results removed

### Removed
- Deprecated root `benchmarks/` folder (contents superseded by `tests/performance/`)
- `src/nimasync_simple.nim` — orphan file with typo in name, never exported

## [1.1.0] - 2025-11-02

### Added
- MPSC (Multi-Producer Single-Consumer) channel mode
- `ChannelMode.MPSC` enum value for multi-producer support
- Wait-free MPSC algorithm using atomic fetchAdd (based on dbittman + JCTools)
- Comprehensive MPSC benchmark suite (tests/performance/benchmark_mpsc.nim, 316 lines)
- MPSC unit tests (tests/unit/test_mpsc_channel.nim, 259 lines)

### Performance (Verified Benchmarks)
- SPSC micro-benchmark: 558M ops/sec peak, 31ns P99 latency
- SPSC realistic threaded: ~35M ops/sec
- MPSC 2 producers: 15M ops/sec micro, ~15M realistic
- MPSC 4 producers: 8.5M ops/sec
- MPSC 8 producers: 5.3M ops/sec (memory-bandwidth limited)
- Key finding: SPSC is 3.5× faster than MPSC in realistic threaded workloads

### Changed
- Updated README with MPSC usage examples and honest performance data
- Updated Nimble badge to v1.1.0
- Expanded performance documentation with micro vs realistic comparison

### Implementation Details
- Wait-free producer coordination via atomic CAS
- Cache-line padding prevents false sharing
- ORC-safe memory management, zero GC pauses
- Single consumer uses relaxed atomic operations

## [1.0.0] - 2025-11-02

### Added
- Production-ready SPSC channels with verified performance
- 7-benchmark validation suite (Tokio, Go, LMAX Disruptor methodologies)
- Latency profiling: 20ns p50, 31ns p99, 50ns p99.9
- Published to official Nimble registry
- GitHub issue templates for contributors

### Performance (Verified)
- Peak micro-benchmark: 558M ops/sec
- Average across suite: 551M ops/sec  
- Realistic threaded: ~35M ops/sec
- P99 latency: 31ns
- 0% contention under stress (500K ops)
- Async overhead: 512K ops/sec (Chronos wrappers)

### Documentation
- BENCHMARKS.md with methodology
- Performance validation in tests/performance/
- Roadmap updated to show v1.0.0 complete
- Honest disclaimers about micro vs realistic performance

### Fixed
- Added test binaries to .gitignore

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
