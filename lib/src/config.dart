/// Configuration for tick size and offline caps.
class SimulationConfig {
  /// Fixed tick duration in milliseconds.
  final int dtMs;

  /// Maximum offline window in milliseconds.
  final int maxOfflineMs;

  /// Hard cap on total ticks applied during offline progress.
  final int maxTicksTotal;

  /// Number of ticks to apply per offline chunk.
  final int maxTicksPerChunk;

  /// Creates a config with fixed tick size and safety caps.
  SimulationConfig({
    this.dtMs = 1000,
    this.maxOfflineMs = 1000 * 60 * 60 * 24,
    this.maxTicksTotal = 100000,
    this.maxTicksPerChunk = 1000,
  }) {
    if (dtMs <= 0) {
      throw ArgumentError.value(dtMs, 'dtMs', 'Must be > 0');
    }
    if (maxOfflineMs < 0) {
      throw ArgumentError.value(maxOfflineMs, 'maxOfflineMs', 'Must be >= 0');
    }
    if (maxTicksTotal < 0) {
      throw ArgumentError.value(maxTicksTotal, 'maxTicksTotal', 'Must be >= 0');
    }
    if (maxTicksPerChunk <= 0) {
      throw ArgumentError.value(
        maxTicksPerChunk,
        'maxTicksPerChunk',
        'Must be > 0',
      );
    }
  }
}
