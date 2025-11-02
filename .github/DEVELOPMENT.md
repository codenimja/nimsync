# Development Guidelines

## Commit Best Practices

### Size Guidelines

Keep commits focused and atomic:

**Good commit sizes:**
- Single feature or fix
- Related changes only
- Under 500 lines changed (guideline, not hard limit)
- One logical unit of work

**Avoid:**
- Mixing unrelated changes
- Large initial dumps (split into logical commits)
- Multiple features in one commit
- Documentation + code changes (separate when possible)

### When to Split Commits

If your commit includes multiple of these, consider splitting:
- Feature implementation
- Test additions
- Documentation updates
- Refactoring
- Bug fixes

### Example Split Strategy

Instead of:
```
feat: add MPSC with tests and docs (1000+ lines)
```

Do:
```
feat(channels): implement MPSC core algorithm
test(channels): add MPSC unit tests
test(performance): add MPSC benchmark suite
docs: update README for MPSC support
```

## Revert Strategy

### When to Revert

Use `git revert` for:
- Published commits (already pushed)
- Tagged releases
- Shared branches

### When to Amend/Reset

Use `git commit --amend` or `git reset` for:
- Local commits only (not pushed)
- Work-in-progress branches
- Before creating PR

### Best Practice

Before pushing:
```bash
# Review your changes
git log --oneline -5
git diff origin/main

# Amend if needed (local only)
git commit --amend

# Once pushed, use revert
git revert <commit-hash>
```

## Code Review Checklist

Before submitting PR:
- [ ] Commits follow Conventional Commits format
- [ ] Each commit is focused and atomic
- [ ] Tests pass locally
- [ ] Benchmarks run without regression
- [ ] Documentation updated
- [ ] No debug code or commented blocks
- [ ] Author email consistent (codenimja)
