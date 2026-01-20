import 'dart:convert';

import 'package:idle_core/idle_core.dart';
import 'package:test/test.dart';

/// State used for simulation engine tests.
class TestState extends SimulationState {
  /// Current counter value.
  final int counter;

  /// Increment per tick.
  final int rate;

  /// Creates a new test state.
  const TestState({required this.counter, required this.rate});

  /// Returns a copy with updated values.
  TestState copyWith({int? counter, int? rate}) {
    return TestState(
      counter: counter ?? this.counter,
      rate: rate ?? this.rate,
    );
  }

  /// Converts state to JSON.
  @override
  Map<String, dynamic> toJson() => {'counter': counter, 'rate': rate};
}

/// Action that adjusts the rate.
class AdjustRate extends SimulationAction {
  /// Amount to add to the rate.
  final int delta;

  /// Creates an adjust action.
  const AdjustRate(this.delta);
}

/// Fake clock for time-based tests.
class FakeSimulationClock implements SimulationClock {
  int _nowMs;

  /// Creates a fake clock starting at [_nowMs].
  FakeSimulationClock(this._nowMs);

  /// Returns the current fake time.
  @override
  int nowMs() => _nowMs;

  /// Advances time by [deltaMs].
  void advance(int deltaMs) {
    _nowMs += deltaMs;
  }
}

/// Reducer used for tests.
TestState reducer(TestState state, SimulationAction action) {
  if (action is TickAction) {
    return state.copyWith(counter: state.counter + state.rate);
  }
  if (action is AdjustRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Runs simulation engine tests.
void main() {
  test('determinism for identical inputs', () {
    final config = SimulationConfig(
      dtMs: 1000,
    );

    final engineA = SimulationEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final engineB = SimulationEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    engineA.tick(count: 10);
    engineA.dispatch(const AdjustRate(1));
    engineA.tick(count: 2);

    engineB.tick(count: 10);
    engineB.dispatch(const AdjustRate(1));
    engineB.tick(count: 2);

    expect(engineA.state.toJson(), equals(engineB.state.toJson()));
  });

  test('offline caps are enforced', () {
    final config = SimulationConfig(
      dtMs: 1000,
      maxOfflineMs: 4000,
      maxTicksTotal: 2,
      maxTicksPerChunk: 10,
    );

    final engine = SimulationEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final result = engine.applyOffline(lastObservedMs: 0, nowMs: 10000);
    expect(result.ticksApplied, equals(2));
    expect(result.ticksRequested, equals(4));
    expect(result.ticksCapped, equals(2));
    expect(result.wasClamped, isTrue);
    expect(result.wasCapped, isTrue);
    expect(result.state.counter, equals(2));
  });

  test('offline chunking splits work', () {
    final config = SimulationConfig(
      dtMs: 1000,
      maxOfflineMs: 10000,
      maxTicksTotal: 10,
      maxTicksPerChunk: 2,
    );

    final engine = SimulationEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final result = engine.applyOffline(lastObservedMs: 0, nowMs: 5000);
    expect(result.ticksApplied, equals(5));
    expect(result.chunks, equals(3));
  });

  test('offline handles negative delta', () {
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(),
      reducer: reducer,
      state: const TestState(counter: 5, rate: 1),
    );

    final result = engine.applyOffline(lastObservedMs: 10000, nowMs: 0);
    expect(result.ticksApplied, equals(0));
    expect(result.clampedDeltaMs, equals(0));
    expect(result.appliedDeltaMs, equals(0));
    expect(result.wasBackwards, isTrue);
    expect(result.state.counter, equals(5));
  });

  test('offline exposes unapplied delta', () {
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(dtMs: 1000),
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final result = engine.applyOffline(lastObservedMs: 0, nowMs: 3500);
    expect(result.appliedDeltaMs, equals(3000));
    expect(result.unappliedDeltaMs, equals(500));
  });

  test('offline result computes next last-observed timestamp', () {
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(),
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final result = engine.applyOffline(lastObservedMs: 1000, nowMs: 3500);
    expect(result.appliedDeltaMs, equals(2000));
    expect(result.nextLastObservedMs(1000), equals(3000));
  });

  test('offline uses injected clock when nowMs is omitted', () {
    final clock = FakeSimulationClock(3500);
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(),
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
      clock: clock,
    );

    final result = engine.applyOffline(lastObservedMs: 0);
    expect(result.ticksApplied, equals(3));
    expect(result.state.counter, equals(3));
  });

  test('tickForDuration converts ms to ticks', () {
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(),
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final result = engine.tickForDuration(2500);
    expect(result.ticksApplied, equals(2));
    expect(result.state.counter, equals(2));
  });

  test('replay applies actions in order', () {
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(),
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
    );

    final result = engine.replay(<SimulationAction>[
      const TickAction(1000),
      const AdjustRate(2),
      const TickAction(1000),
    ]);

    expect(result.ticksApplied, equals(2));
    expect(result.state.counter, equals(4));
    expect(result.state.rate, equals(3));
  });

  test('offline matches repeated ticks', () {
    final config = SimulationConfig(
      dtMs: 1000,
      maxOfflineMs: 20000,
      maxTicksTotal: 100,
      maxTicksPerChunk: 5,
    );

    for (var ticks = 0; ticks <= 10; ticks++) {
      final engineA = SimulationEngine<TestState>(
        config: config,
        reducer: reducer,
        state: const TestState(counter: 0, rate: 1),
      );

      final engineB = SimulationEngine<TestState>(
        config: config,
        reducer: reducer,
        state: const TestState(counter: 0, rate: 1),
      );

      engineA.applyOffline(lastObservedMs: 0, nowMs: ticks * 1000);
      engineB.tick(count: ticks);

      expect(engineA.state.toJson(), equals(engineB.state.toJson()));
    }
  });

  test('json snapshot stays stable', () {
    final config = SimulationConfig(
      dtMs: 1000,
    );

    final engine = SimulationEngine<TestState>(
      config: config,
      reducer: reducer,
      state: const TestState(counter: 0, rate: 2),
    );

    engine.tick(count: 2);
    engine.dispatch(const AdjustRate(1));
    engine.tick(count: 2);

    final snapshot = jsonEncode(engine.state.toJson());
    expect(snapshot, equals('{"counter":10,"rate":3}'));
  });

  test('fake clock is injectable', () {
    final clock = FakeSimulationClock(0);
    final engine = SimulationEngine<TestState>(
      config: SimulationConfig(),
      reducer: reducer,
      state: const TestState(counter: 0, rate: 1),
      clock: clock,
    );

    clock.advance(1234);
    expect(engine.clock.nowMs(), equals(1234));
  });

  test('manual clock supports set and advance', () {
    final clock = ManualSimulationClock(1000);
    expect(clock.nowMs(), equals(1000));
    clock.advance(250);
    expect(clock.nowMs(), equals(1250));
    clock.setMs(42);
    expect(clock.nowMs(), equals(42));
  });
}
