import 'dart:convert';

import 'package:idle_core/idle_core.dart';
import 'package:test/test.dart';

/// State used for idle engine tests.
class TestState extends IdleState {
  /// Current gold amount.
  final int gold;

  /// Gold earned per tick.
  final int rate;

  /// Creates a new test state.
  const TestState({required this.gold, required this.rate});

  /// Returns a copy with updated values.
  TestState copyWith({int? gold, int? rate}) {
    return TestState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

  /// Converts state to JSON.
  @override
  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};
}

/// Action that upgrades the gold rate.
class UpgradeRate extends IdleAction {
  /// Amount to add to the rate.
  final int delta;

  /// Creates an upgrade action.
  const UpgradeRate(this.delta);
}

/// Fake clock for time-based tests.
class FakeTickClock implements TickClock {
  int _nowMs;

  /// Creates a fake clock starting at [_nowMs].
  FakeTickClock(this._nowMs);

  /// Returns the current fake time.
  @override
  int nowMs() => _nowMs;

  /// Advances time by [deltaMs].
  void advance(int deltaMs) {
    _nowMs += deltaMs;
  }
}

/// Reducer used for tests.
TestState reducer(TestState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Resource delta calculator for tests.
Map<String, num> resourceDelta(TestState before, TestState after) {
  return {'gold': after.gold - before.gold};
}

/// Runs idle engine tests.
void main() {
  test('determinism for identical inputs', () {
    final config = IdleConfig<TestState>(
      dtMs: 1000,
      resourceDelta: resourceDelta,
    );

    final engineA = IdleEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
    );

    final engineB = IdleEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
    );

    engineA.tick(count: 10);
    engineA.dispatch(const UpgradeRate(1));
    engineA.tick(count: 2);

    engineB.tick(count: 10);
    engineB.dispatch(const UpgradeRate(1));
    engineB.tick(count: 2);

    expect(engineA.state.toJson(), equals(engineB.state.toJson()));
  });

  test('offline caps are enforced', () {
    final config = IdleConfig<TestState>(
      dtMs: 1000,
      maxOfflineMs: 4000,
      maxTicksTotal: 2,
      maxTicksPerChunk: 10,
      resourceDelta: resourceDelta,
    );

    final engine = IdleEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
    );

    final result = engine.applyOffline(0, 10000);
    expect(result.ticksApplied, equals(2));
    expect(result.ticksRequested, equals(4));
    expect(result.ticksCapped, equals(2));
    expect(result.wasClamped, isTrue);
    expect(result.wasCapped, isTrue);
    expect(result.state.gold, equals(2));
  });

  test('offline chunking splits work', () {
    final config = IdleConfig<TestState>(
      dtMs: 1000,
      maxOfflineMs: 10000,
      maxTicksTotal: 10,
      maxTicksPerChunk: 2,
    );

    final engine = IdleEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
    );

    final result = engine.applyOffline(0, 5000);
    expect(result.ticksApplied, equals(5));
    expect(result.chunks, equals(3));
  });

  test('offline handles negative delta', () {
    final engine = IdleEngine<TestState>(
      config: IdleConfig<TestState>(),
      reducer: reducer,
      state: const TestState(gold: 5, rate: 1),
    );

    final result = engine.applyOffline(10000, 0);
    expect(result.ticksApplied, equals(0));
    expect(result.clampedDeltaMs, equals(0));
    expect(result.appliedDeltaMs, equals(0));
    expect(result.state.gold, equals(5));
  });

  test('offline from clock uses injected clock', () {
    final clock = FakeTickClock(3500);
    final engine = IdleEngine<TestState>(
      config: IdleConfig<TestState>(),
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
      clock: clock,
    );

    final result = engine.applyOfflineFromClock(0);
    expect(result.ticksApplied, equals(3));
    expect(result.state.gold, equals(3));
  });

  test('tickForDuration converts ms to ticks', () {
    final engine = IdleEngine<TestState>(
      config: IdleConfig<TestState>(),
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
    );

    final result = engine.tickForDuration(2500);
    expect(result.ticksApplied, equals(2));
    expect(result.state.gold, equals(2));
  });

  test('replay applies actions in order', () {
    final engine = IdleEngine<TestState>(
      config: IdleConfig<TestState>(),
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
    );

    final result = engine.replay(<IdleAction>[
      const IdleTickAction(1000),
      const UpgradeRate(2),
      const IdleTickAction(1000),
    ]);

    expect(result.ticksApplied, equals(2));
    expect(result.state.gold, equals(4));
    expect(result.state.rate, equals(3));
  });

  test('offline matches repeated ticks', () {
    final config = IdleConfig<TestState>(
      dtMs: 1000,
      maxOfflineMs: 20000,
      maxTicksTotal: 100,
      maxTicksPerChunk: 5,
    );

    for (var ticks = 0; ticks <= 10; ticks++) {
      final engineA = IdleEngine<TestState>(
        config: config,
        reducer: reducer,
        state: const TestState(gold: 0, rate: 1),
      );

      final engineB = IdleEngine<TestState>(
        config: config,
        reducer: reducer,
        state: const TestState(gold: 0, rate: 1),
      );

      engineA.applyOffline(0, ticks * 1000);
      engineB.tick(count: ticks);

      expect(engineA.state.toJson(), equals(engineB.state.toJson()));
    }
  });

  test('json snapshot stays stable', () {
    final config = IdleConfig<TestState>(
      dtMs: 1000,
      resourceDelta: resourceDelta,
    );

    final engine = IdleEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(gold: 0, rate: 2),
    );

    engine.tick(count: 2);
    engine.dispatch(const UpgradeRate(1));
    engine.tick(count: 2);

    final snapshot = jsonEncode(engine.state.toJson());
    expect(snapshot, equals('{"gold":10,"rate":3}'));
  });

  test('fake clock is injectable', () {
    final clock = FakeTickClock(0);
    final engine = IdleEngine<TestState>(
      config: IdleConfig<TestState>(),
      reducer: reducer,
      state: const TestState(gold: 0, rate: 1),
      clock: clock,
    );

    clock.advance(1234);
    expect(engine.clock.nowMs(), equals(1234));
  });
}
