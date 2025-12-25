# idle_core

Deterministic idle game simulation core for Dart: fixed ticks, offline progress,
and replay. Pure Dart, no Flutter dependency.

## What makes it different

- Deterministic tick engine with replayable action logs for debugging and saves.
- Offline progress with caps and chunking for predictable performance.
- Pure Dart core that runs on server, CLI, or Flutter without platform deps.
- Test-friendly clocks and offline diagnostics for safer time handling.

If you need persistence or Flutter lifecycle hooks, use the companion
packages and feed timestamps into idle_core.

## Quick start

Add the dependency:

```yaml
dependencies:
  idle_core: ^0.2.2
```

Minimal usage:

```dart
import 'dart:io';

import 'package:idle_core/idle_core.dart';

class GameState extends IdleState {
  final int gold;
  final int rate;

  const GameState({required this.gold, required this.rate});

  GameState copyWith({int? gold, int? rate}) {
    return GameState(
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

GameState reducer(GameState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

void main() {
  final engine = IdleEngine<GameState>(
    config: IdleConfig<GameState>(dtMs: 1000),
    reducer: reducer,
    state: const GameState(gold: 0, rate: 1),
  );

  engine.tick(count: 5);
  engine.dispatch(const UpgradeRate(2));
  engine.tick(count: 3);

  var lastSeenMs = 0;
  final nowMs = 10 * 1000;
  final offline = engine.applyOfflineWindow(
    lastSeenMs: lastSeenMs,
    nowMs: nowMs,
  );

  lastSeenMs = offline.nextLastSeenMs(lastSeenMs);
  stdout.writeln('Final: ${offline.state.toJson()}');
}
```

## Capability demos

Deterministic replay (same inputs -> same outputs):

```dart
final actions = <IdleAction>[
  const IdleTickAction(1000),
  const IdleTickAction(1000),
  const UpgradeRate(2),
  const IdleTickAction(1000),
];

final engineA = IdleEngine<GameState>(
  config: IdleConfig<GameState>(),
  reducer: reducer,
  state: const GameState(gold: 0, rate: 1),
);
final engineB = IdleEngine<GameState>(
  config: IdleConfig<GameState>(),
  reducer: reducer,
  state: const GameState(gold: 0, rate: 1),
);

final replayA = engineA.replay(actions);
final replayB = engineB.replay(actions);
print(replayA.state.toJson() == replayB.state.toJson()); // true
```

Offline caps + leftover time visibility:

```dart
final engine = IdleEngine<GameState>(
  config: IdleConfig<GameState>(
    dtMs: 1000,
    maxOfflineMs: 60 * 1000,
    maxTicksTotal: 5,
  ),
  reducer: reducer,
  state: const GameState(gold: 0, rate: 1),
);

final result = engine.applyOfflineWindow(lastSeenMs: 0, nowMs: 20 * 1000);
print(result.ticksApplied); // 5
print(result.unappliedDeltaMs); // 15000 (caps + partial ticks)
```

Time control for tests:

```dart
final clock = ManualTickClock(0);
final engine = IdleEngine<GameState>(
  config: IdleConfig<GameState>(),
  reducer: reducer,
  state: const GameState(gold: 0, rate: 1),
  clock: clock,
);

clock.advance(2500);
final result = engine.applyOfflineFromClock(0);
print(result.ticksApplied); // 2
```

See the runnable demos in `example/main.dart` and `example/replay_demo.dart`.

## Core concepts

State and reducer:

- State is immutable and JSON-serializable.
- Reducer is pure and deterministic.
- Tick logic is driven by `IdleTickAction(dtMs)`.

Determinism checklist:

- Do not call `DateTime.now()` inside reducers.
- Do not use randomness unless the seed is stored in state.
- Only mutate state via returned copies.

## Tick flow

- `IdleEngine.tick(count)` applies `IdleTickAction(dtMs)` repeatedly.
- `IdleEngine.step(dtMs, count)` uses a custom dt.
- `IdleEngine.dispatch(action)` applies a non-tick action.
- `IdleEngine.tickForDuration(deltaMs)` converts a duration to ticks.
- `IdleEngine.replay(actions)` replays a deterministic action list.

## Offline progress

```dart
final result = engine.applyOfflineWindow(
  lastSeenMs: lastSeenMs,
  nowMs: nowMs,
);
```

Offline processing:

- `delta = clamp(now - lastSeen, 0, maxOfflineMs)`
- `ticks = floor(delta / dtMs)` then capped by `maxTicksTotal`
- Work is chunked by `maxTicksPerChunk`

Safety helpers:

- `result.unappliedDeltaMs` reports leftover time (caps or partial ticks).
- `result.wasBackwards` flags negative deltas.
- `result.nextLastSeenMs(lastSeenMs)` advances by applied ticks.

## Integration contract (recommended)

Persist only two things: `state.toJson()` and `lastSeenMs`.

```dart
// Implement GameState.fromJson in your state class.
final savePayload = {
  'state': engine.state.toJson(),
  'lastSeenMs': lastSeenMs,
};

final restoredState = GameState.fromJson(
  Map<String, dynamic>.from(savePayload['state'] as Map),
);
final restoredLastSeenMs = savePayload['lastSeenMs'] as int;

final restoredEngine = IdleEngine<GameState>(
  config: IdleConfig<GameState>(dtMs: 1000),
  reducer: reducer,
  state: restoredState,
);

final offline = restoredEngine.applyOfflineWindow(
  lastSeenMs: restoredLastSeenMs,
  nowMs: nowMs,
);

lastSeenMs = offline.nextLastSeenMs(restoredLastSeenMs);
```

## Events and resource deltas

Use `EventBus` to collect reducer events and `resourceDelta` to summarize state:

```dart
final bus = EventBus();
final reducerWithEvents = (GameState state, IdleAction action) {
  if (action is IdleTickAction) {
    final nextGold = state.gold + state.rate;
    if (state.gold < 10 && nextGold >= 10) {
      bus.emit('milestone:gold-10');
    }
    return state.copyWith(gold: nextGold);
  }
  return state;
};
final config = IdleConfig<GameState>(
  eventBus: bus,
  resourceDelta: (before, after) => {
    'gold': after.gold - before.gold,
  },
);
final engine = IdleEngine<GameState>(
  config: config,
  reducer: reducerWithEvents,
  state: const GameState(gold: 0, rate: 1),
);

engine.tick(count: 1);
print(engine.tick().events);
```

## Tools

Sanity-check determinism locally (includes upgrades + replay):

```bash
dart run tool/determinism_check.dart
```

The tool uses a non-tick action to validate replay order:

```dart
class UpgradeRate extends IdleAction {
  final int delta;
  const UpgradeRate(this.delta);
}

final actions = <IdleAction>[
  const IdleTickAction(1000),
  const UpgradeRate(2),
  const IdleTickAction(1000),
];
```

## Related packages

- `idle_save` for save/load helpers and serialization patterns.
- `idle_flutter` for Flutter lifecycle integration and timestamps.

## API overview

- `IdleEngine` orchestrates ticks and offline application.
- `IdleConfig` defines time step and safety caps.
- `IdleState` is immutable and JSON-serializable.
- `IdleReducer` is a pure function `(state, action) -> state`.
- `TickClock` is injectable for tests.
- `TickResult` and `OfflineResult` summarize progress.
- `EventBus` optionally collects events for result snapshots.
- Helpers: `tickForDuration`, `applyOfflineFromClock`, `applyOfflineWindow`, `replay`.

## Comparison

| Feature              | idle_core | idle detector packages |
| -------------------- | --------- | ---------------------- |
| Offline simulation   | Yes       | No                     |
| Deterministic replay | Yes       | No                     |
| Pure Dart runtime    | Yes       | No                     |
| Inactivity detection | No        | Yes                    |
