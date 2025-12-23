import 'actions.dart';
import 'clock.dart';
import 'config.dart';
import 'results.dart';
import 'state.dart';

abstract class OfflineApplier<S extends IdleState> {
  OfflineResult<S> applyOffline(int lastSeenMs, int nowMs);
}

class IdleEngine<S extends IdleState> implements OfflineApplier<S> {
  final IdleConfig<S> config;
  final IdleReducer<S> reducer;
  final TickClock clock;
  S _state;

  IdleEngine({
    required this.config,
    required this.reducer,
    required S state,
    TickClock? clock,
  })  : _state = state,
        clock = clock ?? SystemTickClock();

  S get state => _state;

  TickResult<S> tick({int count = 1}) {
    return step(config.dtMs, count: count);
  }

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

  TickResult<S> dispatch(IdleAction action) {
    final before = _state;
    _state = reducer(_state, action);
    return _tickResult(before, 0);
  }

  @override
  OfflineResult<S> applyOffline(int lastSeenMs, int nowMs) {
    final requestedDeltaMs = nowMs - lastSeenMs;
    final clampedDeltaMs = _clamp(
      requestedDeltaMs,
      lower: 0,
      upper: config.maxOfflineMs,
    );
    final ticksRequested = clampedDeltaMs ~/ config.dtMs;
    final ticksCapped = ticksRequested > config.maxTicksTotal
        ? config.maxTicksTotal
        : ticksRequested;

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

int _clamp(int value, {required int lower, required int upper}) {
  if (value < lower) {
    return lower;
  }
  if (value > upper) {
    return upper;
  }
  return value;
}
