#!/bin/bash

# Nimsync Benchmark Runner
# Runs all benchmarks and generates comprehensive performance reports

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BENCHMARKS_DIR="$SCRIPT_DIR"
REPORTS_DIR="$BENCHMARKS_DIR/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORTS_DIR/benchmark_report_$TIMESTAMP.txt"
JSON_REPORT="$REPORTS_DIR/benchmark_results_$TIMESTAMP.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$REPORT_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$REPORT_FILE"
}

# Initialize report file
cat > "$REPORT_FILE" << EOF
Nimsync Benchmark Report
========================
Generated: $(date)
System: $(uname -a)
CPU: $(nproc) cores
Memory: $(free -h | grep '^Mem:' | awk '{print $2}')

EOF

# Initialize JSON report
cat > "$JSON_REPORT" << EOF
{
  "timestamp": "$TIMESTAMP",
  "system": {
    "os": "$(uname -s)",
    "cpu_cores": $(nproc),
    "memory": "$(free -h | grep '^Mem:' | awk '{print $2}')"
  },
  "benchmarks": []
}
EOF

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    if ! command -v nim &> /dev/null; then
        missing_deps+=("nim")
    else
        NIM_VERSION=$(nim --version | head -1 | cut -d' ' -f4)
        log_info "Nim version: $NIM_VERSION"
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    else
        JQ_VERSION=$(jq --version | head -1)
        log_info "jq version: $JQ_VERSION"
    fi

    if ! nimble list --installed 2>/dev/null | grep -q chronos; then
        log_warning "Chronos dependency not found. Please run 'nimble install' in the project root."
        missing_deps+=("chronos")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  Ubuntu/Debian: sudo apt update && sudo apt install ${missing_deps[*]}"
        echo "  macOS: brew install ${missing_deps[*]}"
        echo "  Other systems: Please install Nim from https://nim-lang.org/"
        echo "                 and jq from your package manager"
        echo ""
        echo "After installing dependencies, run 'nimble install' in the project root."
        return 1
    fi

    log_success "All dependencies check passed"
    return 0
}

# Run single benchmark
run_benchmark() {
    local benchmark_name="$1"
    local benchmark_file="$2"

    log_info "Running $benchmark_name benchmark..."

    if [ ! -f "$benchmark_file" ]; then
        log_error "Benchmark file not found: $benchmark_file"
        return 1
    fi

    local start_time=$(date +%s.%3N)

    # Run benchmark with timing
    if nim c -d:release -r "$benchmark_file" >> "$REPORT_FILE" 2>&1; then
        local end_time=$(date +%s.%3N)
        local duration=$(echo "$end_time - $start_time" | bc)

        log_success "$benchmark_name completed in ${duration}s"

        # Add to JSON report
        jq --arg name "$benchmark_name" \
           --arg duration "$duration" \
           '.benchmarks += [{"name": $name, "duration": $duration, "status": "passed"}]' \
           "$JSON_REPORT" > "${JSON_REPORT}.tmp" && mv "${JSON_REPORT}.tmp" "$JSON_REPORT"

        return 0
    else
        local end_time=$(date +%s.%3N)
        local duration=$(echo "$end_time - $start_time" | bc)

        log_error "$benchmark_name failed after ${duration}s"

        # Add to JSON report
        jq --arg name "$benchmark_name" \
           --arg duration "$duration" \
           '.benchmarks += [{"name": $name, "duration": $duration, "status": "failed"}]' \
           "$JSON_REPORT" > "${JSON_REPORT}.tmp" && mv "${JSON_REPORT}.tmp" "$JSON_REPORT"

        return 1
    fi
}

# Generate summary report
generate_summary() {
    log_info "Generating benchmark summary..."

    local total_benchmarks=$(jq '.benchmarks | length' "$JSON_REPORT")
    local passed_benchmarks=$(jq '.benchmarks | map(select(.status == "passed")) | length' "$JSON_REPORT")
    local failed_benchmarks=$(jq '.benchmarks | map(select(.status == "failed")) | length' "$JSON_REPORT")
    local total_time=$(jq '.benchmarks | map(.duration | tonumber) | add' "$JSON_REPORT")

    cat >> "$REPORT_FILE" << EOF

Benchmark Summary
=================
Total benchmarks run: $total_benchmarks
Passed: $passed_benchmarks
Failed: $failed_benchmarks
Total execution time: ${total_time}s

EOF

    if [ "$failed_benchmarks" -eq 0 ]; then
        log_success "All benchmarks passed!"
    else
        log_warning "$failed_benchmarks benchmark(s) failed"
    fi

    # Performance recommendations
    cat >> "$REPORT_FILE" << EOF
Performance Recommendations
===========================
- Review failed benchmarks for potential issues
- Compare results across different runs for consistency
- Monitor system resources during benchmark execution
- Consider hardware-specific optimizations

Report files saved:
- Text report: $REPORT_FILE
- JSON data: $JSON_REPORT

EOF
}

# Main execution
main() {
    log_info "Starting Nimsync Benchmark Suite"
    echo ""

    if ! check_dependencies; then
        exit 1
    fi
    echo ""

    local failed_count=0

    # Run all benchmarks in order of complexity
    run_benchmark "Basic Async Operations" "$BENCHMARKS_DIR/basic_async_benchmark.nim" || ((failed_count++))
    run_benchmark "TaskGroup Performance" "$BENCHMARKS_DIR/taskgroup_benchmark.nim" || ((failed_count++))
    run_benchmark "Channel Throughput" "$BENCHMARKS_DIR/channels_benchmark.nim" || ((failed_count++))
    run_benchmark "Stream Processing" "$BENCHMARKS_DIR/streams_benchmark.nim" || ((failed_count++))
    run_benchmark "Full System Integration" "$BENCHMARKS_DIR/full_system_benchmark.nim" || ((failed_count++))

    echo ""
    generate_summary

    # Exit with appropriate code
    if [ "$failed_count" -eq 0 ]; then
        log_success "Benchmark suite completed successfully"
        exit 0
    else
        log_error "Benchmark suite completed with $failed_count failure(s)"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Nimsync Benchmark Runner"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --report-only        Generate summary from existing results"
        echo "  --clean              Clean benchmark artifacts"
        echo ""
        echo "Environment variables:"
        echo "  NIMSYNC_BENCH_ITERATIONS    Number of iterations per benchmark"
        echo "  NIMSYNC_BENCH_DURATION      Benchmark duration in seconds"
        echo "  NIMSYNC_BENCH_CONCURRENCY   Number of concurrent operations"
        echo ""
        exit 0
        ;;
    "--report-only")
        if [ -f "$JSON_REPORT" ]; then
            generate_summary
        else
            log_error "No benchmark results found. Run benchmarks first."
            exit 1
        fi
        ;;
    "--clean")
        echo -e "${BLUE}[INFO]${NC} Cleaning benchmark artifacts..."
        rm -rf "$REPORTS_DIR"
        find "$BENCHMARKS_DIR" -name "*.exe" -o -name "*.bin" -o -name "*_benchmark" | xargs rm -f 2>/dev/null || true
        echo -e "${GREEN}[SUCCESS]${NC} Cleaned benchmark artifacts"
        ;;
    *)
        main
        ;;
esac