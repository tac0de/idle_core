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

class TickResult<S extends IdleState> {
  final S state;
  final int ticksApplied;
  final Map<String, num> resourcesDelta;
  final List<Object> events;

  TickResult({
    required this.state,
    required this.ticksApplied,
    Map<String, num>? resourcesDelta,
    List<Object>? events,
  })  : resourcesDelta = _freezeDelta(resourcesDelta),
        events = _freezeEvents(events);
}

class OfflineResult<S extends IdleState> {
  final S state;
  final int ticksApplied;
  final int chunks;
  final int requestedDeltaMs;
  final int clampedDeltaMs;
  final int ticksRequested;
  final int ticksCapped;
  final int appliedDeltaMs;
  final Map<String, num> resourcesDelta;
  final List<Object> events;

  OfflineResult({
    required this.state,
    required this.ticksApplied,
    required this.chunks,
    required this.requestedDeltaMs,
    required this.clampedDeltaMs,
    required this.ticksRequested,
    required this.ticksCapped,
    required this.appliedDeltaMs,
    Map<String, num>? resourcesDelta,
    List<Object>? events,
  })  : resourcesDelta = _freezeDelta(resourcesDelta),
        events = _freezeEvents(events);
}
