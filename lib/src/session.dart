import 'clock.dart';
import 'config.dart';
import 'engine.dart';
import 'results.dart';
import 'save.dart';
import 'state.dart';

/// Wraps an engine with last-seen tracking for safer offline flow.
class IdleSession<S extends IdleState> {
  /// Engine that owns the current state.
  final IdleEngine<S> engine;

  int _lastSeenMs;

  /// Creates a session with [engine] and persisted [lastSeenMs].
  IdleSession({required this.engine, required int lastSeenMs})
      : _lastSeenMs = lastSeenMs;

  /// Last seen timestamp in milliseconds.
  int get lastSeenMs => _lastSeenMs;

  /// Applies offline progress and advances [lastSeenMs] by applied ticks.
  OfflineResult<S> applyOffline({int? nowMs}) {
    final now = nowMs ?? engine.clock.nowMs();
    final result = engine.applyOffline(_lastSeenMs, now);
    _lastSeenMs = result.nextLastSeenMs(_lastSeenMs);
    return result;
  }

  /// Marks the session as seen at [nowMs] or the current clock time.
  void markSeen({int? nowMs}) {
    _lastSeenMs = nowMs ?? engine.clock.nowMs();
  }

  /// Captures a save snapshot and updates [lastSeenMs].
  IdleSave<S> snapshot(IdleSaveCodec<S> codec, {int? nowMs}) {
    final now = nowMs ?? engine.clock.nowMs();
    _lastSeenMs = now;
    return codec.capture(state: engine.state, lastSeenMs: _lastSeenMs);
  }

  /// Captures a save snapshot as JSON and updates [lastSeenMs].
  Map<String, dynamic> snapshotJson(IdleSaveCodec<S> codec, {int? nowMs}) {
    return codec.encode(snapshot(codec, nowMs: nowMs));
  }
}

/// Bundles game logic, config, and serialization for easy reuse.
class IdleGame<S extends IdleState> {
  /// Engine configuration.
  final IdleConfig<S> config;

  /// Game reducer.
  final IdleReducer<S> reducer;

  /// State codec for save/load.
  final IdleStateCodec<S> stateCodec;

  /// Creates a reusable game definition.
  const IdleGame({
    required this.config,
    required this.reducer,
    required this.stateCodec,
  });

  /// Creates an engine with the provided [state].
  IdleEngine<S> createEngine({required S state, TickClock? clock}) {
    return IdleEngine<S>(
      config: config,
      reducer: reducer,
      state: state,
      clock: clock,
    );
  }

  /// Creates a session with persisted [lastSeenMs].
  IdleSession<S> createSession({
    required S state,
    required int lastSeenMs,
    TickClock? clock,
  }) {
    return IdleSession<S>(
      engine: createEngine(state: state, clock: clock),
      lastSeenMs: lastSeenMs,
    );
  }

  /// Creates a session from a decoded save.
  IdleSession<S> openSession({required IdleSave<S> save, TickClock? clock}) {
    return createSession(
      state: save.state,
      lastSeenMs: save.lastSeenMs,
      clock: clock,
    );
  }

  /// Convenience accessor for the configured save codec.
  IdleSaveCodec<S> get saveCodec => IdleSaveCodec<S>(stateCodec: stateCodec);
}
