# Git Hooks

This directory contains git hooks for maintaining code quality and consistency.

## commit-msg

Validates commit messages follow Conventional Commits format.

Format: `type(scope): description`

Allowed types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- chore: Maintenance tasks
- refactor: Code restructuring
- test: Test additions/changes
- perf: Performance improvements
- ci: CI/CD changes
- revert: Revert previous commit
- style: Code style changes
- build: Build system changes

Examples:
- `feat(channels): add MPSC support`
- `fix(async): correct polling timeout`
- `docs: update README performance numbers`

## Installation

Hooks are automatically active when you clone the repository. If you need to reinstall:

```bash
chmod +x .git/hooks/commit-msg
```

## Bypassing Hooks

Not recommended, but possible with:

```bash
git commit --no-verify -m "your message"
```
