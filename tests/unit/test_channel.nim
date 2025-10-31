## Basic Channel Tests

import nimsync

when isMainModule:
  # Test SPSC channel basic functionality
  let chan = newChannel[int](16, ChannelMode.SPSC)

  # Test send/receive
  assert chan.trySend(42) == true
  assert chan.trySend(43) == true

  var value: int
  assert chan.tryReceive(value) == true
  assert value == 42

  assert chan.tryReceive(value) == true
  assert value == 43

  # Should be empty now
  assert chan.tryReceive(value) == false

  echo "✅ All channel tests passed!"