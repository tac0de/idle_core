import 'dart:convert';
import 'dart:io';

import 'package:idle_core/idle_core.dart';

/// State for the replay and offline demo.
class DemoState extends IdleState {
  /// Current gold amount.
  final int gold;

  /// Gold earned per tick.
  final int rate;

  /// Creates a new demo state.
  const DemoState({required this.gold, required this.rate});

  /// Returns a copy with updated values.
  DemoState copyWith({int? gold, int? rate}) {
    return DemoState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

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

/// Creates a reducer that emits events on upgrades and milestones.
IdleReducer<DemoState> reducer(EventBus bus) {
  return (DemoState state, IdleAction action) {
    if (action is IdleTickAction) {
      final nextGold = state.gold + state.rate;
      if (state.gold < 5 && nextGold >= 5) {
        bus.emit('milestone:gold-5');
      }
      return state.copyWith(gold: nextGold);
    }
    if (action is UpgradeRate) {
      bus.emit('upgrade:+${action.delta}');
      return state.copyWith(rate: state.rate + action.delta);
    }
    return state;
  };
}

/// Runs the replay and offline demo.
void main() {
  final actions = <IdleAction>[
    const IdleTickAction(1000),
    const IdleTickAction(1000),
    const UpgradeRate(2),
    const IdleTickAction(1000),
  ];

  final busA = EventBus();
  final configA = IdleConfig<DemoState>(
    dtMs: 1000,
    maxOfflineMs: 60 * 1000,
    maxTicksTotal: 5,
    maxTicksPerChunk: 2,
    eventBus: busA,
    resourceDelta: (before, after) => {
      'gold': after.gold - before.gold,
    },
  );

  final engineA = IdleEngine<DemoState>(
    config: configA,
    reducer: reducer(busA),
    state: const DemoState(gold: 0, rate: 1),
  );

  final busB = EventBus();
  final engineB = IdleEngine<DemoState>(
    config: IdleConfig<DemoState>(dtMs: 1000, eventBus: busB),
    reducer: reducer(busB),
    state: const DemoState(gold: 0, rate: 1),
  );

  final replayA = engineA.replay(actions);
  final replayB = engineB.replay(actions);
  final same = jsonEncode(replayA.state.toJson()) ==
      jsonEncode(replayB.state.toJson());

  stdout.writeln('Replay deterministic: $same');
  stdout.writeln('Replay delta: ${replayA.resourcesDelta}');
  stdout.writeln('Replay events: ${replayA.events}');

  var lastSeenMs = 0;
  final offline = engineA.applyOfflineWindow(
    lastSeenMs: lastSeenMs,
    nowMs: 20 * 1000,
  );

  lastSeenMs = offline.nextLastSeenMs(lastSeenMs);
  stdout.writeln('Offline ticks applied: ${offline.ticksApplied}');
  stdout.writeln('Unapplied ms: ${offline.unappliedDeltaMs}');
  stdout.writeln('Next lastSeenMs: $lastSeenMs');
}
