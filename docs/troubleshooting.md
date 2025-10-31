# Troubleshooting

## Common Issues

### Compilation Errors

**"Cannot find module chronos"**
```bash
nimble install chronos
```

**View types errors with experimental features**
```nim
# Remove --experimental:views if causing issues
# Or update to newer Nim version
```

### Performance Issues

**Low throughput**
- Use SPSC channels instead of MPMC when possible
- Compile with `-d:release --opt:speed`
- Check for blocking operations in hot paths

**High latency**
- Reduce buffer sizes for lower latency
- Use `BackpressurePolicy.Block` instead of `Drop`
- Avoid allocations in message handlers

### Memory Issues

**Memory leaks**
- Ensure channels and streams are properly closed
- Use `--mm:orc` for better memory management
- Check actor cleanup in supervision

**High memory usage**
- Reduce channel/stream buffer sizes
- Use batch operations instead of individual sends
- Monitor with `getGlobalStats()` when `defined(statistics)`

### Deadlocks

**Channel deadlocks**
- Always have matching senders/receivers
- Use timeouts for reliability
- Consider using `BackpressurePolicy.Drop` for fire-and-forget

**TaskGroup hangs**
- Check for infinite loops in tasks
- Ensure proper cancellation handling
- Use timeouts around `taskGroup` calls

## Debugging

### Enable Statistics
```nim
# Compile with -d:statistics
when defined(statistics):
  let stats = getGlobalStats()
  echo "Tasks: ", stats.totalTasks
  echo "Messages: ", stats.totalMessages
```

### Performance Profiling
```bash
# Compile with profiling
nim c -d:release --profiler:on --stackTrace:on app.nim

# Run and check profile
./app
cat profile_results.txt
```

### Enable Debug Info
```nim
# Compile with debug info
nim c -d:debug app.nim

# Or enable specific debugging
when defined(debug):
  scope.setName("my-scope")
  echo scope.getStackTrace()
```

## Performance Monitoring

```nim
# Check component stats
let chanStats = channel.getStats()
let streamStats = stream.getStats()
let actorStats = actor.getStats()

# System-wide monitoring
let systemStats = getGlobalStats()
echo "Total operations: ", systemStats.totalMessages
```

## Known Limitations

- View types require Nim 1.6+ and experimental features
- Some optimizations only work with ORC memory management
- SIMD features require specific CPU architectures
- Statistics collection adds small overhead