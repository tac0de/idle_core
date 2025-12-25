/// Clock abstraction to provide current time in milliseconds.
abstract class TickClock {
  /// Returns the current time in milliseconds since epoch.
  int nowMs();
}

/// System clock backed by [DateTime.now].
class SystemTickClock implements TickClock {
  /// Creates a system-backed clock.
  SystemTickClock();

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

/// Manually controlled clock useful for tests and replays.
class ManualTickClock implements TickClock {
  int _nowMs;

  /// Creates a manual clock starting at [nowMs].
  ManualTickClock([int nowMs = 0]) : _nowMs = nowMs;

  @override
  int nowMs() => _nowMs;

  /// Sets the current time to [nowMs].
  void setMs(int nowMs) {
    _nowMs = nowMs;
  }

  /// Advances time by [deltaMs].
  void advance(int deltaMs) {
    _nowMs += deltaMs;
  }
}
