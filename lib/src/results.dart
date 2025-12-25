import 'state.dart';

Map<String, num> _freezeDelta(Map<String, num>? delta) {
  if (delta == null || delta.isEmpty) {
    return const <String, num>{};
  }
  return Map<String, num>.unmodifiable(delta);
}

List<Object> _freezeEvents(List<Object>? events) {
  if (events == null || events.isEmpty) {
    return const <Object>[];
  }
  return List<Object>.unmodifiable(events);
}

/// Summary of a single or batched tick operation.
class TickResult<S extends IdleState> {
  /// Final state after ticks are applied.
  final S state;

  /// Number of ticks applied.
  final int ticksApplied;

  /// Optional resource delta summary.
  final Map<String, num> resourcesDelta;

  /// Events drained from the event bus.
  final List<Object> events;

  /// Creates a tick result snapshot.
  TickResult({
    required this.state,
    required this.ticksApplied,
    Map<String, num>? resourcesDelta,
    List<Object>? events,
  })  : resourcesDelta = _freezeDelta(resourcesDelta),
        events = _freezeEvents(events);
}

/// Summary of offline progress application.
class OfflineResult<S extends IdleState> {
  /// Final state after offline ticks are applied.
  final S state;

  /// Number of ticks applied.
  final int ticksApplied;

  /// Number of chunks used during offline processing.
  final int chunks;

  /// Raw requested delta in milliseconds.
  final int requestedDeltaMs;

  /// Clamped delta after applying [IdleConfig.maxOfflineMs].
  final int clampedDeltaMs;

  /// Ticks requested based on clamped delta.
  final int ticksRequested;

  /// Ticks after applying [IdleConfig.maxTicksTotal].
  final int ticksCapped;

  /// True if the delta was clamped by [IdleConfig.maxOfflineMs].
  final bool wasClamped;

  /// True if the tick count was capped by [IdleConfig.maxTicksTotal].
  final bool wasCapped;

  /// Milliseconds actually applied (ticksApplied * dtMs).
  final int appliedDeltaMs;

  /// Optional resource delta summary.
  final Map<String, num> resourcesDelta;

  /// Events drained from the event bus.
  final List<Object> events;

  /// Creates an offline result snapshot.
  OfflineResult({
    required this.state,
    required this.ticksApplied,
    required this.chunks,
    required this.requestedDeltaMs,
    required this.clampedDeltaMs,
    required this.ticksRequested,
    required this.ticksCapped,
    required this.wasClamped,
    required this.wasCapped,
    required this.appliedDeltaMs,
    Map<String, num>? resourcesDelta,
    List<Object>? events,
  })  : resourcesDelta = _freezeDelta(resourcesDelta),
        events = _freezeEvents(events);

  /// Computes the next last-seen timestamp based on applied ticks.
  int nextLastSeenMs(int lastSeenMs) => lastSeenMs + appliedDeltaMs;

  /// True if the requested delta was negative (clock moved backwards).
  bool get wasBackwards => requestedDeltaMs < 0;

  /// Milliseconds not applied due to caps or partial ticks.
  int get unappliedDeltaMs => clampedDeltaMs - appliedDeltaMs;
}
