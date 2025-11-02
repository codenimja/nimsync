# NUMA: Cross-Socket Performance Validation

## Description
Validate and optimize nimsync's performance on NUMA (Non-Uniform Memory Access) architectures with multiple CPU sockets.

## Current Status
- **Testing**: ❌ Not validated on multi-socket systems
- **Optimization**: ⚠️ Unknown if cache-line alignment helps/hurts across sockets
- **Blocking**: Large server deployments (2+ socket systems)

## Why NUMA Matters
Modern servers often have multiple CPU sockets:
- **2-socket systems**: AMD EPYC, Intel Xeon (common in cloud)
- **4-socket systems**: High-end servers
- **8+ socket systems**: Specialized HPC

NUMA introduces memory access latency differences:
- **Local memory**: ~70ns access time
- **Remote socket**: ~140ns access time (2x slower!)
- **Cache effects**: Cross-socket cache coherency traffic

## Current Unknowns
1. **Does SPSC work well across sockets?**
   - If producer on socket 0, consumer on socket 1, does 615M ops/sec hold?
   - Or does it degrade to 100M ops/sec due to remote memory access?

2. **Is cache-line alignment (64 bytes) optimal?**
   - Current padding prevents false sharing on single socket
   - But does it cause excessive cache coherency traffic on NUMA?

3. **Should we pin threads to cores?**
   - Prevents migration across sockets
   - But reduces OS flexibility

## Testing Needed
### Hardware
- Access to 2+ socket AMD EPYC or Intel Xeon system
- `numactl` for thread/memory pinning
- Hardware performance counters (perf)

### Benchmarks
```bash
# Same socket (baseline)
numactl --cpunodebind=0 --membind=0 ./benchmark_spsc_simple

# Cross socket (worst case)
# Producer on socket 0, consumer on socket 1
taskset -c 0 ./producer & taskset -c 64 ./consumer

# Measure:
# - Throughput degradation
# - Latency increase
# - Cache miss rates (perf stat -e LLC-load-misses)
```

## Expected Outcomes
1. **Quantify NUMA penalty**: "Cross-socket reduces throughput by X%"
2. **Optimization guide**: "For best performance on NUMA, do Y"
3. **Code changes if needed**: 
   - NUMA-aware allocation (`numa_alloc_onnode`)
   - Socket-specific optimizations
   - Documentation on thread pinning

## Acceptance Criteria
- [ ] Benchmarks run on 2-socket system
- [ ] Document same-socket vs cross-socket performance
- [ ] Recommendations for NUMA deployments
- [ ] (Optional) NUMA-aware channel allocation API
- [ ] CI tests on NUMA hardware (if available)

## Reference Implementations
- **DPDK**: Heavily NUMA-optimized, good patterns to study
- **ScyllaDB**: Sharded architecture for NUMA
- **LMAX Disruptor**: NUMA considerations in ring buffer

## Help Wanted
**Skills needed**: NUMA architecture understanding, systems programming, performance analysis

**Resources**:
- `man numa` and `man numactl`
- Intel's NUMA optimization guide
- AMD EPYC tuning guide

**Hardware access**: This is the blocker - need access to multi-socket system for testing

---

**Priority**: Medium 🟡 (not blocking single-socket deployments)
**Difficulty**: Medium 🟡 (testing complexity, not implementation)
**Impact**: Medium 🟡 (only affects large server deployments)

## Current Workaround
For now, users on NUMA systems should:
- Pin producer/consumer to same socket
- Use one channel per socket
- Benchmark their specific workload

But proper validation and docs would be better!
