#!/bin/bash
# nimsync Benchmark Runner
#
# Executes comprehensive benchmarks and organizes results

set -e

# Directories
BENCHMARK_ROOT="benchmarks"
RESULTS_DIR="$BENCHMARK_ROOT/results"
DATA_DIR="$BENCHMARK_ROOT/data"
REPORTS_DIR="$BENCHMARK_ROOT/reports"
LOGS_DIR="$BENCHMARK_ROOT/logs"

# Timestamp for this run
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_DIR="$RESULTS_DIR/run_$TIMESTAMP"
DATA_RUN_DIR="$DATA_DIR/run_$TIMESTAMP"

mkdir -p "$RUN_DIR" "$DATA_RUN_DIR" "$REPORTS_DIR" "$LOGS_DIR"

echo "Starting nimsync benchmark suite at $TIMESTAMP"
echo "Results will be stored in: $RUN_DIR"
echo "Data will be stored in: $DATA_RUN_DIR"

# Function to run a benchmark
run_benchmark() {
    local benchmark_name=$1
    local benchmark_file=$2
    local log_file="$LOGS_DIR/${benchmark_name}_${TIMESTAMP}.log"
    
    echo "Running $benchmark_name..."
    
    # Compile and run benchmark
    if nim c -d:release --opt:speed -r "$benchmark_file" 2>&1 | tee "$log_file"; then
        echo "$benchmark_name completed successfully"
        
        # Extract and save metrics
        grep -E "(throughput|ops/sec|latency|memory|duration|performance)" "$log_file" > "$RUN_DIR/${benchmark_name}_metrics.txt" 2>/dev/null || true
        
        # Save raw data if available
        if [ -f "raw_benchmark_data.json" ]; then
            mv "raw_benchmark_data.json" "$DATA_RUN_DIR/${benchmark_name}_data.json"
        fi
    else
        echo "$benchmark_name failed, check $log_file"
    fi
}

# Run performance benchmarks
echo "Running performance benchmarks..."
run_benchmark "channel_throughput" "tests/performance/benchmark_stress.nim"
run_benchmark "stress_tests" "tests/stress/extreme_stress_test.nim"

# Generate summary report
REPORT_FILE="$REPORTS_DIR/benchmark_summary_$TIMESTAMP.md"
cat > "$REPORT_FILE" << EOF
# nimsync Benchmark Summary
Date: $(date)
System: $(uname -a)
Nim Version: $(nim --version 2>&1 | head -1)
nimsync Version: $(grep version nimsync.nimble | head -1 | cut -d '"' -f 2)

## Key Results
$(find "$RUN_DIR" -name "*_metrics.txt" -exec cat {} \; 2>/dev/null || echo "No metrics files found")

## Performance Highlights
- SPSC Channel Throughput: 
- MPMC Channel Throughput: 
- Task Spawn Rate:
- Cancellation Rate:

For detailed results, see individual benchmark logs in $LOGS_DIR
EOF

echo "Benchmark suite completed!"
echo "Summary report: $REPORT_FILE"
echo "Detailed results: $RUN_DIR"
echo "Raw data: $DATA_RUN_DIR"