# Benchmarks

## What's Here

This directory contains **internal stress tests** for validation during development:

```
stress_tests/
├── backpressure_test.nim       - Buffer overflow handling
├── comprehensive_stress_test.nim - Combined load scenarios
├── database_pool_test.nim      - Connection pooling validation
├── failure_mode_test.nim       - Error handling under stress
├── http_load_test.nim          - HTTP client stress testing
├── long_running.nim            - 24-hour endurance test
├── memory_pressure_test.nim    - GC pressure validation
├── mixed_workload_test.nim     - Real-world mixed operations
├── mpmc_stress_test.nim        - Future MPMC validation (SPSC only in v1.0.0)
├── real_world_scenarios.nim    - Application-like workloads
├── spawn_stress_test.nim       - Task spawn rate validation
├── streaming_pipeline.nim      - Stream backpressure testing
└── websocket_load_test.nim     - WebSocket concurrent connections
```

## Running Internal Stress Tests

```bash
# Run all stress tests
cd tests/benchmarks/stress_tests
./run_suite

# Or individual tests
nim c -r long_running.nim
nim c -r memory_pressure_test.nim
```

## Contributing Benchmarks

To contribute performance benchmarks or comparative studies, please submit PRs to this repository.

See the main [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) for contribution guidelines.
