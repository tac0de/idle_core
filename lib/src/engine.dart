import 'actions.dart';
import 'clock.dart';
import 'config.dart';
import 'results.dart';
import 'state.dart';
import 'offline_helpers.dart';

/// Applies offline progress using millisecond timestamps.
abstract class OfflineRunner<S extends SimulationState> {
  /// Applies offline progress from [lastObservedMs] to [nowMs].
  OfflineResult<S> applyOffline({
    required int lastObservedMs,
    int? nowMs,
  });
}

/// Deterministic simulation engine that applies ticks and offline progress.
class SimulationEngine<S extends SimulationState> implements OfflineRunner<S> {
  /// Engine configuration with tick size and safety caps.
  final SimulationConfig config;

  /// Reducer that maps actions to new state.
  final SimulationReducer<S> reducer;

  /// Clock used for time-based helpers.
  final SimulationClock clock;

  S _state;

  /// Creates an engine with config, reducer, and initial [state].
  SimulationEngine({
    required this.config,
    required this.reducer,
    required S state,
    SimulationClock? clock,
  })  : _state = state,
        clock = clock ?? SystemSimulationClock();

  /// Current state snapshot.
  S get state => _state;

  /// Applies [count] ticks using the configured [SimulationConfig.dtMs].
  TickResult<S> tick({int count = 1}) {
    return step(config.dtMs, count: count);
  }

  /// Applies [count] ticks using a custom [dtMs].
  TickResult<S> step(int dtMs, {int count = 1}) {
    if (dtMs <= 0) {
      throw ArgumentError.value(dtMs, 'dtMs', 'Must be > 0');
    }
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Must be >= 0');
    }
    final action = TickAction(dtMs);
    for (var i = 0; i < count; i++) {
      _state = reducer(_state, action);
    }
    return _tickResult(count);
  }

  /// Applies a non-tick [action] and returns a result snapshot.
  TickResult<S> dispatch(SimulationAction action) {
    _state = reducer(_state, action);
    return _tickResult(0);
  }

  /// Applies all [actions] in order and returns a result snapshot.
  ///
  /// The returned [TickResult.ticksApplied] counts only [TickAction] items.
  TickResult<S> replay(Iterable<SimulationAction> actions) {
    var ticksApplied = 0;
    for (final action in actions) {
      if (action is TickAction) {
        ticksApplied += 1;
      }
      _state = reducer(_state, action);
    }
    return _tickResult(ticksApplied);
  }

  /// Applies ticks for the given [deltaMs] duration using [SimulationConfig.dtMs].
  ///
  /// Any remainder smaller than one tick is discarded.
  TickResult<S> tickForDuration(int deltaMs) {
    final ticks = calcTicksForDelta(deltaMs, config.dtMs);
    return tick(count: ticks);
  }

  /// Applies offline progress from [lastObservedMs] to [nowMs].
  @override
  OfflineResult<S> applyOffline({
    required int lastObservedMs,
    int? nowMs,
  }) {
    final now = nowMs ?? clock.nowMs();
    final requestedDeltaMs = now - lastObservedMs;
    final clampedDeltaMs = clampOfflineDeltaMs(
      requestedDeltaMs,
      config.maxOfflineMs,
    );
    final ticksRequested = calcTicksForDelta(clampedDeltaMs, config.dtMs);
    final ticksCapped = ticksRequested > config.maxTicksTotal
        ? config.maxTicksTotal
        : ticksRequested;
    final wasClamped = requestedDeltaMs != clampedDeltaMs;
    final wasCapped = ticksRequested != ticksCapped;

    var ticksApplied = 0;
    var chunks = 0;
    final action = TickAction(config.dtMs);

    while (ticksApplied < ticksCapped) {
      final remaining = ticksCapped - ticksApplied;
      final chunkTicks = remaining > config.maxTicksPerChunk
          ? config.maxTicksPerChunk
          : remaining;
      for (var i = 0; i < chunkTicks; i++) {
        _state = reducer(_state, action);
      }
      ticksApplied += chunkTicks;
      chunks++;
    }

    final appliedDeltaMs = ticksApplied * config.dtMs;

    return OfflineResult<S>(
      state: _state,
      ticksApplied: ticksApplied,
      chunks: chunks,
      requestedDeltaMs: requestedDeltaMs,
      clampedDeltaMs: clampedDeltaMs,
      ticksRequested: ticksRequested,
      ticksCapped: ticksCapped,
      wasClamped: wasClamped,
      wasCapped: wasCapped,
      appliedDeltaMs: appliedDeltaMs,
    );
  }

  TickResult<S> _tickResult(int ticksApplied) {
    return TickResult<S>(
      state: _state,
      ticksApplied: ticksApplied,
    );
  }
}
