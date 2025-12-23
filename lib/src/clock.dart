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
