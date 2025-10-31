# Benchmark Data Organization

This directory contains organized benchmark results and data for nimsync performance validation.

## Directory Structure

- `results/` - Benchmark execution results and output
- `data/` - Raw benchmark data files and measurements  
- `scripts/` - Benchmark execution and analysis scripts
- `reports/` - Generated performance reports and analysis
- `logs/` - Benchmark execution logs and debugging info

## Benchmark Files

### Core Performance Benchmarks
- `basic_async_benchmark.nim` - Fundamental async operation performance
- `channels_benchmark.nim` - Channel throughput and latency tests
- `taskgroup_benchmark.nim` - Task group spawning and management
- `streams_benchmark.nim` - Stream processing performance
- `full_system_benchmark.nim` - Comprehensive system validation

### Performance Categories

#### Channel Benchmarks
- SPSC: Single Producer, Single Consumer (fastest)
- MPSC: Multiple Producer, Single Consumer
- SPMC: Single Producer, Multiple Consumer
- MPMC: Multiple Producer, Multiple Consumer (most flexible)

#### Component Benchmarks
- Task Groups: Structured concurrency performance
- Cancellation: Hierarchical cancellation performance
- Select Operations: Multi-channel coordination
- Actors: Lightweight actor system

#### System Benchmarks
- Memory Usage: Allocation and retention patterns
- Throughput: Operations per second under load
- Latency: P50, P95, P99, P99.9 percentiles
- Scalability: Performance across core counts