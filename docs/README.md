# nimsync Documentation

Welcome to the official documentation for nimsync, a high-performance async runtime for Nim.

## Table of Contents

- [Getting Started](getting_started.md) - Quick start guide and installation
- [API Reference](api.md) - Complete API documentation
- [Performance Guide](performance.md) - Performance tips and benchmarks
- [Testing Guide](testing.md) - Comprehensive test suite documentation
- [Quick Start](quick-start.md) - Rapid prototyping examples
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Ecosystem](ecosystem.md) - Integration with other Nim libraries

## Overview

nimsync provides structured concurrency primitives for Nim applications:

- **Task Groups**: Atomic task lifecycle management with error policies
- **Channels**: Lock-free message passing with multiple modes (SPSC, MPSC, MPMC)
- **Streams**: Backpressure-aware data pipelines with combinators
- **Actors**: Lightweight stateful entities with supervision
- **Cancellation**: Hierarchical cancellation with minimal overhead

## Quick Links

- [GitHub Repository](https://github.com/codenimja/nimsync)
- [Package Registry](https://nimble.directory/package/nimsync)
- [Examples](../examples/)
- [Tests](../tests/)

## Contributing

Documentation improvements are welcome! Please see our [Contributing Guide](../CONTRIBUTING.md) for details.

## License

This documentation is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
