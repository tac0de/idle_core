import 'dart:io';

import 'package:idle_core/idle_core.dart';

/// Example state for a simple idle economy.
class EconomyState extends IdleState {
  /// Current gold amount.
  final int gold;

  /// Gold earned per tick.
  final int rate;

  /// Creates a new economy state.
  const EconomyState({required this.gold, required this.rate});

  /// Returns a copy with updated values.
  EconomyState copyWith({int? gold, int? rate}) {
    return EconomyState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

  /// Creates a state from JSON.
  factory EconomyState.fromJson(Map<String, dynamic> json) {
    return EconomyState(
      gold: json['gold'] as int,
      rate: json['rate'] as int,
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

/// Reducer for the example economy.
EconomyState reducer(EconomyState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Runs the example simulation.
void main() {
  final stateCodec = IdleStateCodec<EconomyState>(
    schemaVersion: 1,
    fromJson: EconomyState.fromJson,
  );
  final game = IdleGame<EconomyState>(
    config: IdleConfig<EconomyState>(
      dtMs: 1000,
      resourceDelta: (before, after) => {
        'gold': after.gold - before.gold,
      },
    ),
    reducer: reducer,
    stateCodec: stateCodec,
  );

  final session = game.createSession(
    state: const EconomyState(gold: 0, rate: 1),
    lastSeenMs: 0,
  );

  session.engine.tick(count: 5);
  session.engine.dispatch(const UpgradeRate(2));
  session.engine.tick(count: 3);

  const nowMs = 10 * 1000;
  final offline = session.applyOffline(nowMs: nowMs);
  final saveJson = session.snapshotJson(game.saveCodec, nowMs: nowMs);
  stdout.writeln('Final: ${offline.state.toJson()}');
  stdout.writeln('Offline ticks: ${offline.ticksApplied}');
  stdout.writeln('Unapplied ms: ${offline.unappliedDeltaMs}');
  stdout.writeln('Save JSON: $saveJson');
}
