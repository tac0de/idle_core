import 'state.dart';

/// Summary of a single or batched tick operation.
class TickResult<S extends SimulationState> {
  /// Final state after ticks are applied.
  final S state;

  /// Number of ticks applied.
  final int ticksApplied;

  /// Creates a tick result snapshot.
  TickResult({
    required this.state,
    required this.ticksApplied,
  });
}

/// Summary of offline progress application.
class OfflineResult<S extends SimulationState> {
  /// Final state after offline ticks are applied.
  final S state;

  /// Number of ticks applied.
  final int ticksApplied;

  /// Number of chunks used during offline processing.
  final int chunks;

  /// Raw requested delta in milliseconds.
  final int requestedDeltaMs;

  /// Clamped delta after applying [SimulationConfig.maxOfflineMs].
  final int clampedDeltaMs;

  /// Ticks requested based on clamped delta.
  final int ticksRequested;

  /// Ticks after applying [SimulationConfig.maxTicksTotal].
  final int ticksCapped;

  /// True if the delta was clamped by [SimulationConfig.maxOfflineMs].
  final bool wasClamped;

  /// True if the tick count was capped by [SimulationConfig.maxTicksTotal].
  final bool wasCapped;

  /// Milliseconds actually applied (ticksApplied * dtMs).
  final int appliedDeltaMs;

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
  });

  /// Computes the next last-observed timestamp based on applied ticks.
  int nextLastObservedMs(int lastObservedMs) =>
      lastObservedMs + appliedDeltaMs;

  /// True if the requested delta was negative (clock moved backwards).
  bool get wasBackwards => requestedDeltaMs < 0;

  /// Milliseconds not applied due to caps or partial ticks.
  int get unappliedDeltaMs => clampedDeltaMs - appliedDeltaMs;
}
