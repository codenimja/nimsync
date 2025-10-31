#!/bin/bash
# Comprehensive Benchmark Runner for nimsync
#
# This script runs all available benchmarks and organizes results in the benchmark directories.
#
# Usage:
#   ./scripts/run_all_benchmarks.sh
#
# Results will be stored in:
#   - benchmarks/results/ - Benchmark execution results
#   - benchmarks/data/    - Raw benchmark data files
#   - benchmarks/reports/ - Generated performance reports
#   - benchmarks/logs/    - Benchmark execution logs

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

# Create directories
mkdir -p "$RUN_DIR" "$DATA_RUN_DIR" "$REPORTS_DIR" "$LOGS_DIR"

echo "🚀 Starting nimsync Comprehensive Benchmark Suite"
echo "📅 Timestamp: $TIMESTAMP"
echo "💾 Results directory: $RUN_DIR"
echo ""

# Function to run a benchmark
run_benchmark() {
    local benchmark_name=$1
    local benchmark_file=$2
    local log_file="$LOGS_DIR/${benchmark_name}_${TIMESTAMP}.log"
    
    echo "🔨 Running $benchmark_name..."
    
    # Check if benchmark file exists
    if [ ! -f "$benchmark_file" ]; then
        echo "⚠️  Skipping $benchmark_name - file not found: $benchmark_file"
        echo "⚠️  Skipping $benchmark_name - file not found: $benchmark_file" >> "$log_file"
        all_benchmarks+=("$benchmark_name")
        failed_benchmarks+=("$benchmark_name")
        return 1
    fi
    
    # Compile the benchmark
    if nim c -d:danger --opt:speed "$benchmark_file" 2>&1 | tee "$log_file"; then
        # Get executable name
        executable=$(basename "$benchmark_file" .nim)
        
        if [ -f "$executable" ]; then
            echo "🏃 Executing $executable..." | tee -a "$log_file"
            if timeout 300s ./"$executable" 2>&1 | tee -a "$log_file"; then
                echo "✅ $benchmark_name completed successfully" | tee -a "$log_file"
                
                # Extract and save metrics
                grep -E "(throughput|ops/sec|latency|memory|duration|performance|benchmark)" "$log_file" > "$RUN_DIR/${benchmark_name}_metrics.txt" 2>/dev/null || true
                
                # Clean up executable
                rm -f "$executable"
                
                return 0
            else
                echo "❌ $benchmark_name execution failed" | tee -a "$log_file"
                return 1
            fi
        else
            echo "❌ $benchmark_name compilation failed (no executable generated)" | tee -a "$log_file"
            return 1
        fi
    else
        echo "❌ $benchmark_name compilation failed" | tee -a "$log_file"
        return 1
    fi
}

# Track results
declare -a all_benchmarks=()
declare -a passed_benchmarks=()
declare -a failed_benchmarks=()

# Core benchmarks from benchmarks/ directory
echo "🔍 Running core benchmarks..."
for bench_file in benchmarks/*_benchmark.nim; do
    if [ -f "$bench_file" ]; then
        bench_name=$(basename "$bench_file" .nim | sed 's/_benchmark//')
        bench_display_name=$(echo "$bench_name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
        
        all_benchmarks+=("$bench_display_name")
        if run_benchmark "$bench_display_name" "$bench_file"; then
            passed_benchmarks+=("$bench_display_name")
        else
            failed_benchmarks+=("$bench_display_name")
        fi
    fi
done

# Performance tests
echo ""
echo "🔍 Running performance tests..."
for perf_test in tests/performance/*.nim; do
    if [ -f "$perf_test" ]; then
        test_name=$(basename "$perf_test" .nim)
        test_display_name=$(echo "$test_name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
        
        all_benchmarks+=("$test_display_name")
        if run_benchmark "$test_display_name" "$perf_test"; then
            passed_benchmarks+=("$test_display_name")
        else
            failed_benchmarks+=("$test_display_name")
        fi
    fi
done

# Stress tests
echo ""
echo "🔍 Running stress tests..."
for stress_test in tests/stress/*.nim; do
    if [ -f "$stress_test" ]; then
        test_name=$(basename "$stress_test" .nim)
        test_display_name=$(echo "$test_name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
        
        all_benchmarks+=("$test_display_name")
        if run_benchmark "$test_display_name" "$stress_test"; then
            passed_benchmarks+=("$test_display_name")
        else
            failed_benchmarks+=("$test_display_name")
        fi
    fi
done

# Additional benchmarks
echo ""
echo "🔍 Running additional benchmarks..."
for additional_bench in bench_*.nim; do
    if [ -f "$additional_bench" ]; then
        bench_name=$(basename "$additional_bench" .nim)
        bench_display_name=$(echo "$bench_name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
        
        all_benchmarks+=("$bench_display_name")
        if run_benchmark "$bench_display_name" "$additional_bench"; then
            passed_benchmarks+=("$bench_display_name")
        else
            failed_benchmarks+=("$bench_display_name")
        fi
    fi
done

# Calculate summary
total_benchmarks=${#all_benchmarks[@]}
passed_count=${#passed_benchmarks[@]}
failed_count=${#failed_benchmarks[@]}

# Generate summary report
REPORT_FILE="$REPORTS_DIR/benchmark_summary_$TIMESTAMP.md"
cat > "$REPORT_FILE" << EOF
# nimsync Benchmark Summary
Date: $(date)
System: $(uname -a)
Nim Version: $(nim --version 2>&1 | head -1)
nimsync Version: $(grep version nimsync.nimble | head -1 | cut -d '"' -f 2)

## Benchmark Results
- Total Benchmarks Run: $total_benchmarks
- Passed: $passed_count
- Failed: $failed_count

## Detailed Results
EOF

for bench in "${all_benchmarks[@]}"; do
    status="FAILED"
    if [[ " ${passed_benchmarks[*]} " == *" $bench "* ]]; then
        status="PASSED"
    fi
    
    echo "- $bench: $status" >> "$REPORT_FILE"
done

# Generate CSV report for data analysis
CSV_FILE="$REPORTS_DIR/benchmark_results_$TIMESTAMP.csv"
echo "Benchmark,Status,Duration,LogFile" > "$CSV_FILE"
for bench in "${all_benchmarks[@]}"; do
    status="FAILED"
    duration="N/A"
    log_file="$LOGS_DIR/${bench// /_}_${TIMESTAMP}.log"
    
    if [[ " ${passed_benchmarks[*]} " == *" $bench "* ]]; then
        status="PASSED"
    fi
    
    # Try to extract duration from log if available
    if [ -f "$log_file" ]; then
        duration_line=$(grep -E "(duration|completed in)" "$log_file" | tail -1)
        if [ -n "$duration_line" ]; then
            duration=$(echo "$duration_line" | grep -oE "[0-9]+\.[0-9]+s" | head -1)
        fi
    fi
    
    echo "$bench,$status,$duration,$log_file" >> "$CSV_FILE"
done

# Print summary to console
echo ""
echo "📊 BENCHMARK SUITE RESULTS SUMMARY"
printf "%-30s %-10s\\n" "Benchmark" "Status"
printf "%-30s %-10s\\n" "---------" "------"
for bench in "${all_benchmarks[@]}"; do
    status="❌ FAILED"
    if [[ " ${passed_benchmarks[*]} " == *" $bench "* ]]; then
        status="✅ PASSED"
    fi
    printf "%-30s %-10s\\n" "$bench" "$status"
done

echo ""
echo "📈 SUMMARY:"
echo "  Total: $total_benchmarks"
echo "  Passed: $passed_count"
echo "  Failed: $failed_count"
echo ""
echo "📁 REPORTS AND LOGS:"
echo "  Summary report: $REPORT_FILE"
echo "  CSV data: $CSV_FILE"
echo "  Logs directory: $LOGS_DIR/"
echo "  Results directory: $RUN_DIR/"

if [ $failed_count -gt 0 ]; then
    echo ""
    echo "⚠️  $failed_count benchmark(s) failed - check logs in $LOGS_DIR/"
    exit 1
else
    echo ""
    echo "🎉 All benchmarks completed successfully!"
fi