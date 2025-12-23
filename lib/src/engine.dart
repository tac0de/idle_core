import 'actions.dart';
import 'clock.dart';
import 'config.dart';
import 'results.dart';
import 'state.dart';
import 'offline_helpers.dart';

/// Applies offline progress using millisecond timestamps.
abstract class OfflineApplier<S extends IdleState> {
  /// Applies offline progress from [lastSeenMs] to [nowMs].
  OfflineResult<S> applyOffline(int lastSeenMs, int nowMs);
}

/// Deterministic idle engine that applies ticks and offline progress.
class IdleEngine<S extends IdleState> implements OfflineApplier<S> {
  /// Engine configuration with tick size and safety caps.
  final IdleConfig<S> config;

  /// Reducer that maps actions to new state.
  final IdleReducer<S> reducer;

  /// Clock used for time-based helpers.
  final TickClock clock;

  S _state;

  /// Creates an engine with config, reducer, and initial [state].
  IdleEngine({
    required this.config,
    required this.reducer,
    required S state,
    TickClock? clock,
  })  : _state = state,
        clock = clock ?? SystemTickClock();

  /// Current state snapshot.
  S get state => _state;

  /// Applies [count] ticks using the configured [IdleConfig.dtMs].
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
    final before = _state;
    final action = IdleTickAction(dtMs);
    for (var i = 0; i < count; i++) {
      _state = reducer(_state, action);
    }
    return _tickResult(before, count);
  }

  /// Applies a non-tick [action] and returns a result snapshot.
  TickResult<S> dispatch(IdleAction action) {
    final before = _state;
    _state = reducer(_state, action);
    return _tickResult(before, 0);
  }

  /// Applies all [actions] in order and returns a result snapshot.
  ///
  /// The returned [TickResult.ticksApplied] counts only [IdleTickAction] items.
  TickResult<S> replay(Iterable<IdleAction> actions) {
    final before = _state;
    var ticksApplied = 0;
    for (final action in actions) {
      if (action is IdleTickAction) {
        ticksApplied += 1;
      }
      _state = reducer(_state, action);
    }
    return _tickResult(before, ticksApplied);
  }

  /// Applies ticks for the given [deltaMs] duration using [IdleConfig.dtMs].
  ///
  /// Any remainder smaller than one tick is discarded.
  TickResult<S> tickForDuration(int deltaMs) {
    final ticks = calcTicksForDelta(deltaMs, config.dtMs);
    return tick(count: ticks);
  }

  /// Applies offline progress from [lastSeenMs] to the current clock time.
  OfflineResult<S> applyOfflineFromClock(int lastSeenMs) {
    return applyOffline(lastSeenMs, clock.nowMs());
  }

  /// Convenience alias for [applyOffline].
  OfflineResult<S> advance(int nowMs, int lastSeenMs) {
    return applyOffline(lastSeenMs, nowMs);
  }

  /// Applies offline progress from [lastSeenMs] to [nowMs].
  @override
  OfflineResult<S> applyOffline(int lastSeenMs, int nowMs) {
    final requestedDeltaMs = nowMs - lastSeenMs;
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

    final before = _state;
    var ticksApplied = 0;
    var chunks = 0;
    final action = IdleTickAction(config.dtMs);

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
      resourcesDelta: _resourceDelta(before, _state),
      events: _drainEvents(),
    );
  }

  TickResult<S> _tickResult(S before, int ticksApplied) {
    return TickResult<S>(
      state: _state,
      ticksApplied: ticksApplied,
      resourcesDelta: _resourceDelta(before, _state),
      events: _drainEvents(),
    );
  }

  Map<String, num> _resourceDelta(S before, S after) {
    final resourceDelta = config.resourceDelta;
    if (resourceDelta == null) {
      return const <String, num>{};
    }
    return resourceDelta(before, after);
  }

  List<Object> _drainEvents() {
    final bus = config.eventBus;
    if (bus == null) {
      return const <Object>[];
    }
    return bus.drain();
  }
}
