#!/bin/bash
# Official Benchmark Suite Runner
# Follows industry best practices for concurrent systems benchmarking

set -e

echo "================================================================================"
echo "nimsync Official Benchmark Suite"
echo "================================================================================"
echo ""
echo "Industry-standard benchmarks following best practices from:"
echo "  • Tokio (Rust async runtime)"
echo "  • Go channels benchmarking"
echo "  • LMAX Disruptor performance testing"
echo ""

BENCHMARKS=(
  "benchmark_spsc_simple:Throughput - Raw channel performance"
  "benchmark_latency:Latency - p50/p95/p99/p99.9 distribution"
  "benchmark_burst:Burst Load - Bursty workload patterns"
  "benchmark_sizes:Buffer Sizing - Optimal channel size"
  "benchmark_stress:Stress Test - Maximum sustainable load"
  "benchmark_concurrent:Async Performance - Real async overhead"
)

RESULTS_DIR="benchmark_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo ""

for benchmark in "${BENCHMARKS[@]}"; do
  IFS=':' read -r name description <<< "$benchmark"
  
  echo "--------------------------------------------------------------------------------"
  echo "Running: $description"
  echo "--------------------------------------------------------------------------------"
  echo ""
  
  # Compile
  echo "Compiling $name..."
  if [[ "$name" == "benchmark_concurrent" ]]; then
    nim c -r "tests/performance/${name}.nim" | tee "$RESULTS_DIR/${name}.txt"
  else
    nim c -d:danger --opt:speed --mm:orc "tests/performance/${name}.nim"
    
    # Run
    echo "Executing..."
    "./tests/performance/${name}" | tee "$RESULTS_DIR/${name}.txt"
  fi
  
  echo ""
  echo "✅ Complete"
  echo ""
done

echo "================================================================================"
echo "Benchmark Suite Complete"
echo "================================================================================"
echo ""
echo "Results saved in: $RESULTS_DIR/"
echo ""
echo "Summary:"
for benchmark in "${BENCHMARKS[@]}"; do
  IFS=':' read -r name description <<< "$benchmark"
  echo "  • $description"
done
echo ""
echo "To view individual results:"
echo "  cat $RESULTS_DIR/benchmark_*.txt"
