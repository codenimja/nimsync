# Contributing to nimsync

Thank you for your interest in contributing to nimsync! This document outlines the guidelines and processes for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Testing](#testing)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)
- [Community](#community)

## Code of Conduct

By participating in this project, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/nimsync.git
   cd nimsync
   ```
3. Create a new branch for your feature/fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Nim 1.6.0 or later (2.0.0+ recommended)
- Chronos 4.0.4 or later
- Git

### Installation

```bash
# Install dependencies
nimble install

# Verify installation
nimble test
```

## Testing

nimsync uses a comprehensive testing framework with unit, integration, performance, and stress tests. All tests must pass before submitting a pull request.

### Test Categories

- **Unit Tests** (`tests/unit/`): Isolated component tests
- **Integration Tests** (`tests/integration/`): Component interaction tests
- **Performance Tests** (`tests/performance/`): Throughput and latency benchmarks
- **Stress Tests** (`tests/stress/`): Extreme load and long-running stability tests
- **End-to-End Tests** (`tests/e2e/`): Complete workflow validation

### Running Tests

```bash
# Run basic tests (recommended for development)
nimble test

# Run quick validation tests
nimble testQuick

# Run comprehensive test suite
nimble testFull

# Run comprehensive benchmark suite (recommended)
./tests/performance/run_all_benchmarks.sh

# Or run individual benchmarks
nimble testPerf

# Run intensive stress tests
nimble testStress
```

### Adding New Tests

1. Choose appropriate test category (unit/integration/performance/stress)
2. Follow existing test patterns in the framework
3. Add performance assertions where applicable
4. Include comprehensive documentation
5. Update CI configuration if needed

## Commit Message Guidelines

We follow Conventional Commits format for all commit messages.

### Format

```
type(scope): description

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance tasks (dependencies, tooling)
- `refactor`: Code restructuring without behavior change
- `test`: Test additions or modifications
- `perf`: Performance improvements
- `ci`: CI/CD configuration changes
- `revert`: Revert previous commit

### Examples

```
feat(channels): add MPSC support
fix(async): correct polling timeout in recv()
docs: update README with verified benchmark data
chore: bump Nim version to 2.2.0
perf(channels): optimize ring buffer allocation
```

### Scope

Optional but recommended. Indicates the module affected:
- `channels`: Channel-related changes
- `async`: Async/await functionality
- `benchmarks`: Performance benchmarks
- `tests`: Test infrastructure

### Enforcement

A commit-msg hook validates format automatically. See `.github/COMMIT_GUIDELINES.md` for details.

## Code Style

### Naming Conventions

- Procedures: `camelCase`
- Types: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Exported names: Suffix with `*`

### Documentation

All public procedures and types must be documented with:
- Clear description of purpose
- Parameter descriptions
- Return value documentation
- Example usage where applicable
- Since version annotation

Example:
```nim
proc myFunction*(input: string): int =
  ## Provides a clear description of what this function does.
  ##
  ## Args:
  ##   input: Description of the input parameter
  ##
  ## Returns:
  ##   Description of the return value
  ##
  ## Usage:
  ##   let result = myFunction("example")
  ##
  ## Since: 0.1.0
  result = input.len
```

## Pull Request Process

1. Ensure all tests pass
2. Update documentation as needed
3. Add tests for new functionality
4. Follow the code style guidelines
5. Write clear, descriptive commit messages
6. Include a detailed description of your changes in the PR

## Reporting Issues

When reporting issues, please include:

- Nim version
- nimsync version
- Operating system
- Steps to reproduce
- Expected behavior
- Actual behavior
- Any relevant logs or error messages

## Community

- [GitHub Discussions](https://github.com/codenimja/nimsync/discussions) - For questions and community discussions
- [GitHub Issues](https://github.com/codenimja/nimsync/issues) - For bug reports and feature requests

## License

By contributing to nimsync, you agree that your contributions will be licensed under the MIT License, as specified in the [LICENSE](LICENSE) file.

---

Thank you for contributing to nimsync!