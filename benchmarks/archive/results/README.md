# Benchmark Results Processing

This directory contains all processed benchmark results for nimsync performance validation.

## Results by Benchmark Type

### Channel Performance
- `spsc_*.json` - Single Producer Single Consumer results
- `mpmc_*.json` - Multiple Producer Multiple Consumer results  
- `mpsc_*.json` - Multiple Producer Single Consumer results
- `spmc_*.json` - Single Producer Multiple Consumer results

### System Performance
- `task_group_*.json` - Task group spawning and management
- `cancellation_*.json` - Cancellation operation performance
- `select_*.json` - Multi-channel select operations
- `actor_*.json` - Actor system performance

### Memory and Scalability
- `memory_*.json` - Memory usage under load
- `scalability_*.json` - Performance across core counts
- `stress_*.json` - Extreme load validation results