## nimsync — Atomic Operation Helpers
##
## Utility functions for atomic operations and memory barriers.

import std/atomics

# Re-export common atomic operations for convenience
export atomics.load, atomics.store, atomics.fetchAdd, atomics.compareExchange