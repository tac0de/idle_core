# idle_core

Deterministic state simulation core for Dart: fixed ticks, offline progression,
replay, and versioned snapshots. Pure Dart, no Flutter dependency.

## Design principles

- Determinism: reducers are pure; no wall-clock reads inside state transitions.
- Replayability: the same actions always produce the same state.
- Explainability: results include ticks applied, caps, and unapplied time.
- Offline-first: long gaps are applied in capped chunks for safety.
- Platform-agnostic: no UI, storage, network, or AI dependencies.

## Out of scope

- UI frameworks (Flutter/Widgets) and lifecycle integration.
- Storage adapters, encryption/signing, or cloud sync.
- Networking, AI/LLM calls, or platform services.

## Install

```yaml
dependencies:
  idle_core: ^0.3.1
```

## Minimal usage

```dart
import 'package:idle_core/idle_core.dart';

class SimState extends SimulationState {
  final int counter;
  final int rate;
  const SimState({required this.counter, required this.rate});

  SimState copyWith({int? counter, int? rate}) {
    return SimState(
      counter: counter ?? this.counter,
      rate: rate ?? this.rate,
    );
  }

  factory SimState.fromJson(Map<String, dynamic> json) {
    return SimState(
      counter: json['counter'] as int,
      rate: json['rate'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'counter': counter, 'rate': rate};
}

SimState reducer(SimState state, SimulationAction action) {
  if (action is TickAction) {
    return state.copyWith(counter: state.counter + state.rate);
  }
  return state;
}

void main() {
  final config = SimulationConfig(dtMs: 1000);
  final engine = SimulationEngine<SimState>(
    config: config,
    reducer: reducer,
    state: const SimState(counter: 0, rate: 1),
  );
  final snapshotCodec = SnapshotCodec<SimState>(
    stateCodec: StateCodec<SimState>(
      schemaVersion: 1,
      fromJson: SimState.fromJson,
    ),
  );

  var lastObservedMs = 0;

  engine.tick(count: 5);
  final offline = engine.applyOffline(
    lastObservedMs: lastObservedMs,
    nowMs: 10 * 1000,
  );
  lastObservedMs = offline.nextLastObservedMs(lastObservedMs);
  final snapshot = snapshotCodec.encodeState(
    state: engine.state,
    lastObservedMs: lastObservedMs,
  );

  print(engine.state.toJson());
  print(snapshot);
}
```

## Offline flow (recommended)

```dart
final offline = engine.applyOffline(
  lastObservedMs: lastObservedMs,
  nowMs: nowMs,
);
lastObservedMs = offline.nextLastObservedMs(lastObservedMs);
final snapshot = snapshotCodec.encodeState(
  state: engine.state,
  lastObservedMs: lastObservedMs,
);
```

## Snapshots and migrations

```dart
final codec = StateCodec<SimState>(
  schemaVersion: 2,
  fromJson: SimState.fromJson,
  migrations: {
    0: (json) => <String, dynamic>{...json, 'rate': 1},
    1: (json) {
      final updated = Map<String, dynamic>.from(json);
      updated['counter'] = updated.remove('count') ?? 0;
      return updated;
    },
  },
);
```

## Replay

```dart
final result = engine.replay(actions);
```

## API snapshot

- `SimulationEngine`, `SimulationConfig`
- `SimulationState`, `SimulationReducer`
- `StateCodec`, `Snapshot`, `SnapshotCodec`
- `SimulationClock`, `OfflineRunner`
- `TickResult`, `OfflineResult`

## Contact

If you find interest in collaborating/contribution or have questions, reach out at
wonyoungchoiseoul@gmail.com.
