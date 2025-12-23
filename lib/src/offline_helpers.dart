/// Clamps an offline delta into the [0, maxOfflineMs] range.
int clampOfflineDeltaMs(int requestedDeltaMs, int maxOfflineMs) {
  if (requestedDeltaMs <= 0) {
    return 0;
  }
  if (requestedDeltaMs > maxOfflineMs) {
    return maxOfflineMs;
  }
  return requestedDeltaMs;
}

/// Converts a millisecond delta into a tick count using floor division.
int calcTicksForDelta(int deltaMs, int dtMs) {
  if (dtMs <= 0) {
    throw ArgumentError.value(dtMs, 'dtMs', 'Must be > 0');
  }
  if (deltaMs <= 0) {
    return 0;
  }
  return deltaMs ~/ dtMs;
}
