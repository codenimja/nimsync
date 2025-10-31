# Benchmark Makefile for nimsync

.PHONY: bench bench-perf bench-stress bench-all results clean-results

# Default benchmark target
bench: bench-perf

# Performance benchmarks
bench-perf:
	@echo "Running performance benchmarks..."
	@./benchmarks/scripts/run_benchmarks.sh

# Stress benchmarks  
bench-stress:
	@echo "Running stress benchmarks..."
	@nim c -d:release --opt:speed tests/stress/extreme_stress_test.nim
	@./extreme_stress_test

# Run all benchmarks
bench-all: bench-perf bench-stress

# View latest results
results:
	@echo "Latest benchmark results:"
	@ls -laht benchmarks/results/ | head -10
	@echo "Latest reports:"
	@ls -laht benchmarks/reports/ | head -5

# Clean benchmark results
clean-results:
	@echo "Cleaning benchmark results..."
	@find benchmarks/results -name "*.txt" -delete 2>/dev/null || true
	@find benchmarks/data -name "*.json" -delete 2>/dev/null || true
	@find benchmarks/logs -name "*.log" -delete 2>/dev/null || true
	@echo "Benchmark results cleaned"

# Benchmark information
bench-info:
	@echo "nimsync Benchmark Suite"
	@echo "======================"
	@echo "Available targets:"
	@echo "  bench       - Run performance benchmarks (default)"
	@echo "  bench-stress - Run stress benchmarks"  
	@echo "  bench-all   - Run all benchmarks"
	@echo "  results     - Show latest results"
	@echo "  clean-results - Clean results directory"
	@echo "  bench-info  - Show this information"