import 'dart:io';

import 'package:idle_core/idle_core.dart';

/// Example state for a simple tick-driven counter.
class CounterState extends SimulationState {
  /// Current counter value.
  final int counter;

  /// Increment per tick.
  final int rate;

  /// Creates a new counter state.
  const CounterState({required this.counter, required this.rate});

  /// Returns a copy with updated values.
  CounterState copyWith({int? counter, int? rate}) {
    return CounterState(
      counter: counter ?? this.counter,
      rate: rate ?? this.rate,
    );
  }

  /// Creates a state from JSON.
  factory CounterState.fromJson(Map<String, dynamic> json) {
    return CounterState(
      counter: json['counter'] as int,
      rate: json['rate'] as int,
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

/// Reducer for the example state.
CounterState reducer(CounterState state, SimulationAction action) {
  if (action is TickAction) {
    return state.copyWith(counter: state.counter + state.rate);
  }
  if (action is AdjustRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Runs the example simulation.
void main() {
  final stateCodec = StateCodec<CounterState>(
    schemaVersion: 1,
    fromJson: CounterState.fromJson,
  );
  final config = SimulationConfig(dtMs: 1000);
  final engine = SimulationEngine<CounterState>(
    config: config,
    reducer: reducer,
    state: const CounterState(counter: 0, rate: 1),
  );

  var lastObservedMs = 0;

  engine.tick(count: 5);
  engine.dispatch(const AdjustRate(2));
  engine.tick(count: 3);

  const nowMs = 10 * 1000;
  final offline = engine.applyOffline(
    lastObservedMs: lastObservedMs,
    nowMs: nowMs,
  );
  lastObservedMs = offline.nextLastObservedMs(lastObservedMs);
  final snapshotCodec = SnapshotCodec<CounterState>(stateCodec: stateCodec);
  final snapshotJson = snapshotCodec.encodeState(
    state: engine.state,
    lastObservedMs: lastObservedMs,
  );
  stdout.writeln('Final: ${engine.state.toJson()}');
  stdout.writeln('Offline ticks: ${offline.ticksApplied}');
  stdout.writeln('Unapplied ms: ${offline.unappliedDeltaMs}');
  stdout.writeln('Snapshot JSON: $snapshotJson');
}
