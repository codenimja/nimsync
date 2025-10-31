# nimsync Benchmark Suite

Complete benchmarking solution for nimsync performance validation.

## Directory Structure

- `results/` - Benchmark execution results and output
- `data/` - Raw benchmark data files and measurements  
- `scripts/` - Benchmark execution and analysis scripts
- `reports/` - Generated performance reports and analysis
- `logs/` - Benchmark execution logs and debugging info

## Benchmarks Available

### Core Performance Benchmarks
- `basic_async_benchmark.nim` - Fundamental async operation performance
- `channels_benchmark.nim` - Channel throughput and latency tests
- `taskgroup_benchmark.nim` - Task group spawning and management
- `streams_benchmark.nim` - Stream processing performance
- `full_system_benchmark.nim` - Comprehensive system validation

### Performance Tests
- `tests/performance/benchmark_stress.nim` - Intensive benchmark and stress tests
- `tests/performance/test_benchmarks.nim` - Performance benchmark suite

### Stress Tests
- `tests/stress/extreme_stress_test.nim` - Extreme stress testing with concurrent operations
- `tests/stress/stress_test_select.nim` - Stress testing for select operations

### Additional Benchmarks
- `bench_select.nim` - Performance benchmark for select operations

## Running Benchmarks

### Method 1: Using the Comprehensive Script (Recommended)
```bash
# Run all benchmarks with comprehensive logging and reporting
./scripts/run_all_benchmarks.sh
```

### Method 2: Using Nimble Tasks
```bash
# Run the basic benchmark
nimble bench

# Run performance tests
nimble testPerf

# Run stress tests
nimble testStress
```

### Method 3: Using Makefile
```bash
# Run performance benchmarks
make test-performance

# Run stress tests
make test-stress
```

### Method 4: Using Benchmarks Directory Makefile
```bash
# Change to benchmarks directory
cd benchmarks

# Run performance benchmarks
make bench

# Run stress benchmarks
make bench-stress

# Run all benchmarks
make bench-all
```

### Method 5: Direct Compilation
```bash
# Compile and run individual benchmarks
nim c -d:danger --opt:speed -r benchmarks/channels_benchmark.nim
```

## Results Organization

The benchmarking system automatically organizes results as follows:

- **Timestamped runs**: Each benchmark run gets a unique timestamp directory
- **Metrics extraction**: Relevant performance metrics are extracted from logs
- **Comprehensive reporting**: Summary reports in both Markdown and JSON formats
- **Detailed logs**: Full execution logs for troubleshooting
- **CSV data**: Structured data for further analysis

### Output Locations

- `benchmarks/reports/benchmark_summary_[timestamp].md` - Human-readable summary
- `benchmarks/reports/benchmark_results_[timestamp].json` - Machine-readable results
- `benchmarks/reports/benchmark_results_[timestamp].csv` - Structured data for analysis
- `benchmarks/logs/[benchmark]_[timestamp].log` - Individual benchmark logs
- `benchmarks/results/run_[timestamp]/[benchmark]_metrics.txt` - Extracted metrics

## Adding New Benchmarks

To add a new benchmark:

1. Create your benchmark file with appropriate naming (`*_benchmark.nim` or in `tests/performance/` or `tests/stress/`)
2. Ensure it follows the existing patterns for benchmark output
3. The comprehensive scripts will automatically detect and run your benchmark