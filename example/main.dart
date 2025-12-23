import 'dart:io';

import 'package:idle_core/idle_core.dart';

class EconomyState extends IdleState {
  final int gold;
  final int rate;

  const EconomyState({required this.gold, required this.rate});

  EconomyState copyWith({int? gold, int? rate}) {
    return EconomyState(
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

EconomyState reducer(EconomyState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

void main() {
  final engine = IdleEngine<EconomyState>(
    config: IdleConfig<EconomyState>(
      dtMs: 1000,
      resourceDelta: (before, after) => {
        'gold': after.gold - before.gold,
      },
    ),
    reducer: reducer,
    state: const EconomyState(gold: 0, rate: 1),
  );

  engine.tick(count: 5);
  engine.dispatch(const UpgradeRate(2));
  engine.tick(count: 3);

  final offline = engine.applyOffline(0, 10 * 1000);
  stdout.writeln('Final: ${offline.state.toJson()}');
  stdout.writeln('Offline ticks: ${offline.ticksApplied}');
}
