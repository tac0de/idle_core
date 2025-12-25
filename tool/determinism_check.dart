import 'dart:io';

import 'package:idle_core/idle_core.dart';

class _CheckState extends IdleState {
  final int gold;
  final int rate;

  const _CheckState({required this.gold, required this.rate});

  _CheckState copyWith({int? gold, int? rate}) {
    return _CheckState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};
}

class UpgradeRate extends IdleAction {
  final int delta;
  const UpgradeRate(this.delta);
}

_CheckState _reducer(_CheckState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Runs a determinism sanity check for replay and offline ticks.
void main() {
  final config = IdleConfig<_CheckState>(
    dtMs: 1000,
    maxOfflineMs: 20000,
    maxTicksTotal: 100,
    maxTicksPerChunk: 5,
  );

  final actions = <IdleAction>[
    const IdleTickAction(1000),
    const UpgradeRate(2),
    const IdleTickAction(1000),
    const IdleTickAction(1000),
  ];

  final replayA = IdleEngine<_CheckState>(
    config: config,
    reducer: _reducer,
    state: const _CheckState(gold: 0, rate: 1),
  ).replay(actions);

  final replayB = IdleEngine<_CheckState>(
    config: config,
    reducer: _reducer,
    state: const _CheckState(gold: 0, rate: 1),
  ).replay(actions);

  if (replayA.state.gold != replayB.state.gold ||
      replayA.state.rate != replayB.state.rate) {
    throw StateError('Replay determinism failed');
  }

  for (var ticks = 0; ticks <= 20; ticks++) {
    final engineA = IdleEngine<_CheckState>(
      config: config,
      reducer: _reducer,
      state: const _CheckState(gold: 0, rate: 1),
    );
    final engineB = IdleEngine<_CheckState>(
      config: config,
      reducer: _reducer,
      state: const _CheckState(gold: 0, rate: 1),
    );

    engineA.dispatch(const UpgradeRate(1));
    engineB.dispatch(const UpgradeRate(1));
    engineA.applyOffline(0, ticks * 1000);
    engineB.tick(count: ticks);

    if (engineA.state.gold != engineB.state.gold ||
        engineA.state.rate != engineB.state.rate) {
      throw StateError('Mismatch at $ticks ticks');
    }
  }

  stdout.writeln('Determinism check passed.');
}
