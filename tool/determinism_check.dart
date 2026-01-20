import 'dart:io';

import 'package:idle_core/idle_core.dart';

class _CheckState extends SimulationState {
  final int counter;
  final int rate;

  const _CheckState({required this.counter, required this.rate});

  _CheckState copyWith({int? counter, int? rate}) {
    return _CheckState(
      counter: counter ?? this.counter,
      rate: rate ?? this.rate,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'counter': counter, 'rate': rate};
}

class AdjustRate extends SimulationAction {
  final int delta;
  const AdjustRate(this.delta);
}

_CheckState _reducer(_CheckState state, SimulationAction action) {
  if (action is TickAction) {
    return state.copyWith(counter: state.counter + state.rate);
  }
  if (action is AdjustRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Runs a determinism sanity check for replay and offline ticks.
void main() {
  final config = SimulationConfig(
    dtMs: 1000,
    maxOfflineMs: 20000,
    maxTicksTotal: 100,
    maxTicksPerChunk: 5,
  );

  final actions = <SimulationAction>[
    const TickAction(1000),
    const AdjustRate(2),
    const TickAction(1000),
    const TickAction(1000),
  ];

  final replayA = SimulationEngine<_CheckState>(
    config: config,
    reducer: _reducer,
    state: const _CheckState(counter: 0, rate: 1),
  ).replay(actions);

  final replayB = SimulationEngine<_CheckState>(
    config: config,
    reducer: _reducer,
    state: const _CheckState(counter: 0, rate: 1),
  ).replay(actions);

  if (replayA.state.counter != replayB.state.counter ||
      replayA.state.rate != replayB.state.rate) {
    throw StateError('Replay determinism failed');
  }

  for (var ticks = 0; ticks <= 20; ticks++) {
    final engineA = SimulationEngine<_CheckState>(
      config: config,
      reducer: _reducer,
      state: const _CheckState(counter: 0, rate: 1),
    );
    final engineB = SimulationEngine<_CheckState>(
      config: config,
      reducer: _reducer,
      state: const _CheckState(counter: 0, rate: 1),
    );

    engineA.dispatch(const AdjustRate(1));
    engineB.dispatch(const AdjustRate(1));
    engineA.applyOffline(lastObservedMs: 0, nowMs: ticks * 1000);
    engineB.tick(count: ticks);

    if (engineA.state.counter != engineB.state.counter ||
        engineA.state.rate != engineB.state.rate) {
      throw StateError('Mismatch at $ticks ticks');
    }
  }

  stdout.writeln('Determinism check passed.');
}
