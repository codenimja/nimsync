# TaskGroup: Nested async macros fail

## Description
TaskGroup implementation has bugs with nested async macro contexts, preventing it from being exported in the public API.

## Current Status
- **Module**: `src/nimsync/group.nim`
- **Exported**: ❌ No (commented out in `src/nimsync.nim`)
- **Blocking**: v0.3.0 release

## Problem Details
Nested async macros fail when TaskGroup tries to coordinate multiple async operations. The macro expansion doesn't properly handle nested contexts.

## Expected Behavior
```nim
import nimsync

proc example() {.async.} =
  var group = newTaskGroup()
  
  group.spawn:
    await someAsyncOp()
  
  group.spawn:
    await anotherAsyncOp()
  
  await group.wait()  # Should wait for all tasks
```

## Current Behavior
- Macro expansion errors in nested async contexts
- Compilation fails with async macro nesting
- Not safe to export publicly

## Impact
- **Structured concurrency** unavailable
- Users must manually track async operations
- Blocks adoption of modern async patterns

## Acceptance Criteria
- [ ] TaskGroup works with nested async macros
- [ ] All tests pass in `tests/unit/test_taskgroup.nim`
- [ ] Can be exported in public API
- [ ] Documentation updated with examples
- [ ] Benchmark shows <5% overhead vs manual coordination

## Related Issues
- Linked to MPSC implementation (needs TaskGroup for coordination)
- Blocks actors system (requires task groups for supervision)

## Help Wanted
**Skills needed**: Nim macro system, async/await internals, Chronos knowledge

**Resources**:
- Chronos async internals: https://github.com/status-im/nim-chronos
- Nim macro docs: https://nim-lang.org/docs/manual.html#macros

**Mentorship**: Available - @boonzy can provide guidance on codebase architecture

---

**Priority**: High 🔴 (blocking v0.3.0)
**Difficulty**: Hard 🔴 (requires deep Nim macro knowledge)
**Impact**: High 🟢 (enables structured concurrency)
