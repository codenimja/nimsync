#!/usr/bin/env python3
"""
Generate visual charts from nimsync benchmark CSV data.

Creates PNG charts for:
- Throughput vs buffer size (from benchmark_sizes.nim)
- Sustained load time-series (from benchmark_sustained.nim)
- Latency distribution histogram (from benchmark_latency.nim)
"""

import sys
import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend

def plot_buffer_sizes(results_dir: str):
    """Generate throughput vs buffer size chart."""
    csv_file = os.path.join(results_dir, "buffer_sizes.csv")
    if not os.path.exists(csv_file):
        print(f"⚠️  Skipping buffer sizes: {csv_file} not found")
        return
    
    df = pd.read_csv(csv_file)
    
    plt.figure(figsize=(12, 6))
    plt.plot(df['buffer_size'], df['throughput_ops_per_sec'] / 1_000_000, 
             marker='o', linewidth=2, markersize=8, color='#2563eb')
    plt.xlabel('Buffer Size (slots)', fontsize=12, fontweight='bold')
    plt.ylabel('Throughput (M ops/sec)', fontsize=12, fontweight='bold')
    plt.title('nimsync SPSC Channel: Throughput vs Buffer Size', 
              fontsize=14, fontweight='bold', pad=20)
    plt.grid(True, alpha=0.3, linestyle='--')
    plt.xscale('log', base=2)
    
    # Add optimal point annotation
    optimal_idx = df['throughput_ops_per_sec'].idxmax()
    optimal_size = df.loc[optimal_idx, 'buffer_size']
    optimal_throughput = df.loc[optimal_idx, 'throughput_ops_per_sec'] / 1_000_000
    plt.annotate(f'Optimal: {optimal_size} slots\n{optimal_throughput:.0f}M ops/sec',
                xy=(optimal_size, optimal_throughput),
                xytext=(optimal_size * 2, optimal_throughput * 0.9),
                arrowprops=dict(arrowstyle='->', color='red', lw=2),
                fontsize=11, fontweight='bold', color='red',
                bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.7))
    
    plt.tight_layout()
    output = os.path.join(results_dir, "chart_buffer_sizes.png")
    plt.savefig(output, dpi=150, bbox_inches='tight')
    print(f"✅ Generated: {output}")
    plt.close()

def plot_sustained_timeseries(results_dir: str):
    """Generate sustained load time-series chart."""
    csv_file = os.path.join(results_dir, "sustained_timeseries.csv")
    if not os.path.exists(csv_file):
        print(f"⚠️  Skipping sustained: {csv_file} not found")
        return
    
    df = pd.read_csv(csv_file)
    
    # Filter to just the 10-second test
    df_10s = df[df['test_name'] == '10-second sustained load']
    
    if len(df_10s) == 0:
        print(f"⚠️  No 10-second data in {csv_file}")
        return
    
    plt.figure(figsize=(14, 6))
    plt.plot(df_10s['elapsed_time_sec'], df_10s['throughput_ops_per_sec'] / 1_000_000,
             linewidth=1.5, alpha=0.7, color='#10b981')
    
    # Add rolling average
    window_size = max(1, len(df_10s) // 50)
    rolling_avg = df_10s['throughput_ops_per_sec'].rolling(window=window_size).mean()
    plt.plot(df_10s['elapsed_time_sec'], rolling_avg / 1_000_000,
             linewidth=3, color='#ef4444', label=f'Rolling Average ({window_size} samples)')
    
    plt.xlabel('Time (seconds)', fontsize=12, fontweight='bold')
    plt.ylabel('Throughput (M ops/sec)', fontsize=12, fontweight='bold')
    plt.title('nimsync SPSC Channel: Sustained Load Stability (10s)', 
              fontsize=14, fontweight='bold', pad=20)
    plt.grid(True, alpha=0.3, linestyle='--')
    plt.legend(fontsize=11)
    
    # Add statistics text
    avg_throughput = df_10s['throughput_ops_per_sec'].mean() / 1_000_000
    min_throughput = df_10s['throughput_ops_per_sec'].min() / 1_000_000
    max_throughput = df_10s['throughput_ops_per_sec'].max() / 1_000_000
    variance = ((max_throughput - min_throughput) / avg_throughput) * 100
    
    stats_text = f"Avg: {avg_throughput:.0f}M ops/sec\nVariance: {variance:.1f}%"
    plt.text(0.02, 0.98, stats_text, transform=plt.gca().transAxes,
             fontsize=11, verticalalignment='top',
             bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
    
    plt.tight_layout()
    output = os.path.join(results_dir, "chart_sustained_timeseries.png")
    plt.savefig(output, dpi=150, bbox_inches='tight')
    print(f"✅ Generated: {output}")
    plt.close()

def plot_latency_distribution(results_dir: str):
    """Generate latency distribution histogram."""
    csv_file = os.path.join(results_dir, "latency_samples.csv")
    if not os.path.exists(csv_file):
        print(f"⚠️  Skipping latency: {csv_file} not found")
        return
    
    df = pd.read_csv(csv_file)
    
    plt.figure(figsize=(12, 6))
    
    # Convert to nanoseconds for readability
    latencies_ns = df['latency_ns']
    
    plt.hist(latencies_ns, bins=50, color='#8b5cf6', alpha=0.7, edgecolor='black')
    plt.xlabel('Latency (nanoseconds)', fontsize=12, fontweight='bold')
    plt.ylabel('Frequency', fontsize=12, fontweight='bold')
    plt.title('nimsync SPSC Channel: Latency Distribution', 
              fontsize=14, fontweight='bold', pad=20)
    plt.grid(True, alpha=0.3, linestyle='--', axis='y')
    
    # Add percentile lines
    p50 = latencies_ns.quantile(0.50)
    p99 = latencies_ns.quantile(0.99)
    p999 = latencies_ns.quantile(0.999)
    
    plt.axvline(p50, color='green', linestyle='--', linewidth=2, label=f'P50: {p50:.0f}ns')
    plt.axvline(p99, color='orange', linestyle='--', linewidth=2, label=f'P99: {p99:.0f}ns')
    plt.axvline(p999, color='red', linestyle='--', linewidth=2, label=f'P99.9: {p999:.0f}ns')
    
    plt.legend(fontsize=11)
    
    plt.tight_layout()
    output = os.path.join(results_dir, "chart_latency_distribution.png")
    plt.savefig(output, dpi=150, bbox_inches='tight')
    print(f"✅ Generated: {output}")
    plt.close()

def main():
    # Find most recent benchmark_results directory
    results_dirs = glob.glob("benchmark_results_*")
    if not results_dirs:
        print("❌ No benchmark_results_* directories found!")
        print("Run benchmarks first: cd tests/performance && ./run_all_benchmarks.sh")
        sys.exit(1)
    
    # Use most recent (sort by name, which includes timestamp)
    latest_dir = sorted(results_dirs)[-1]
    
    print("=" * 60)
    print("nimsync Benchmark Chart Generator")
    print("=" * 60)
    print(f"Using results from: {latest_dir}")
    print()
    
    # Generate charts
    plot_buffer_sizes(latest_dir)
    plot_sustained_timeseries(latest_dir)
    plot_latency_distribution(latest_dir)
    
    print()
    print("=" * 60)
    print("Chart Generation Complete")
    print("=" * 60)
    print()
    print("Charts saved in:", latest_dir)
    print("  - chart_buffer_sizes.png")
    print("  - chart_sustained_timeseries.png")
    print("  - chart_latency_distribution.png")
    print()
    print("Visual candy ready for README! 🍭")

if __name__ == "__main__":
    main()
