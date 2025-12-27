# idle_core

Deterministic idle game core engine SDK for Dart: fixed ticks, offline progress,
replay, and versioned saves. Pure Dart, no Flutter dependency.

## SDK positioning

idle_core is a core engine SDK for idle/tycoon/incremental games. It standardizes
the simulation loop, offline progression, and save evolution so UI and platform
layers stay clean and independent.

You can now rely on:

- Deterministic tick simulation and replay for debugging and balance testing.
- First-class offline progress with caps, chunking, and diagnostics.
- Version-safe save/load with migrations via `IdleStateCodec` + `IdleSaveCodec`.
- Session helpers that keep `lastSeenMs` correct and hard to misuse.

## What makes it different

- Deterministic tick engine with replayable action logs for debugging and saves.
- Offline progress with caps and chunking for predictable performance.
- Pure Dart core that runs on server, CLI, or Flutter without platform deps.
- Test-friendly clocks and offline diagnostics for safer time handling.

If you need platform storage or Flutter lifecycle hooks, use the companion
packages and feed timestamps into idle_core. Save serialization and versioning
helpers live in this package.

## Why it is better than ad-hoc logic

- Determinism is enforced by design (tick-only progression, replayable actions).
- Offline logic is bounded and observable (caps, chunks, leftover time).
- Saves evolve safely without silent corruption (explicit migrations).
- Refactors stay cheap because state transitions are explicit and isolated.

## Before vs after (boilerplate reduction)

Before (manual offline + save management):

```dart
final nowMs = clock.nowMs();
var deltaMs = nowMs - lastSeenMs;
if (deltaMs < 0) deltaMs = 0;
if (deltaMs > maxOfflineMs) deltaMs = maxOfflineMs;

var ticks = deltaMs ~/ dtMs;
if (ticks > maxTicksTotal) ticks = maxTicksTotal;

for (var i = 0; i < ticks; i++) {
  state = reducer(state, IdleTickAction(dtMs));
}

lastSeenMs += ticks * dtMs;
save({'state': state.toJson(), 'lastSeenMs': lastSeenMs});
```

After (engine + session + save codec):

```dart
final session = game.createSession(state: state, lastSeenMs: lastSeenMs);
final offline = session.applyOffline(nowMs: nowMs);
final saveJson = session.snapshotJson(game.saveCodec, nowMs: nowMs);
```

## Code comparison (realistic flow)

Shared game logic:

```dart
class GameState {
  final int gold;
  final int rate;
  const GameState({required this.gold, required this.rate});

  GameState copyWith({int? gold, int? rate}) {
    return GameState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};
  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gold: json['gold'] as int,
      rate: json['rate'] as int,
    );
  }
}

GameState reducer(GameState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  return state;
}
```

Without idle_core (manual time, caps, save evolution):

```dart
var state = const GameState(gold: 0, rate: 1);
var lastSeenMs = 0;
const dtMs = 1000;
const maxOfflineMs = 60 * 1000;
const maxTicksTotal = 10000;

final nowMs = clock.nowMs();
var deltaMs = nowMs - lastSeenMs;
if (deltaMs < 0) deltaMs = 0;
if (deltaMs > maxOfflineMs) deltaMs = maxOfflineMs;

var ticks = deltaMs ~/ dtMs;
if (ticks > maxTicksTotal) ticks = maxTicksTotal;

for (var i = 0; i < ticks; i++) {
  state = reducer(state, IdleTickAction(dtMs));
}

lastSeenMs += ticks * dtMs;
save({'schemaVersion': 1, 'state': state.toJson(), 'lastSeenMs': lastSeenMs});
```

With idle_core (engine + session + save codec):

```dart
final game = IdleGame<GameState>(
  config: IdleConfig<GameState>(dtMs: 1000, maxOfflineMs: 60 * 1000),
  reducer: reducer,
  stateCodec: IdleStateCodec<GameState>(
    schemaVersion: 1,
    fromJson: GameState.fromJson,
  ),
);

final session = game.createSession(
  state: const GameState(gold: 0, rate: 1),
  lastSeenMs: 0,
);

final offline = session.applyOffline(nowMs: clock.nowMs());
final saveJson = session.snapshotJson(game.saveCodec, nowMs: clock.nowMs());
```

## Expected developer impact

- Faster iteration: offline/save plumbing becomes a standard, reusable flow.
- Fewer regressions: time handling and caps are centralized and tested.
- Easier refactors: state changes are isolated to reducers and migrations.

## Without vs with idle_core

Without idle_core (typical outcomes):

- Offline logic diverges across features and becomes hard to audit.
- Time bugs slip in (negative deltas, partial ticks, missing caps).
- Save formats drift with no migration path.
- UI and logic become coupled during refactors.

With idle_core (typical outcomes):

- One deterministic tick path for all progression.
- Offline becomes bounded, chunked, and diagnosable.
- Save data has explicit schema and migration steps.
- Reducers keep logic isolated from UI and platform layers.

## Quick start

Add the dependency:

```yaml
dependencies:
  idle_core: ^0.3.0
```

Minimal usage (SDK flow):

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

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gold: json['gold'] as int,
      rate: json['rate'] as int,
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
  final stateCodec = IdleStateCodec<GameState>(
    schemaVersion: 1,
    fromJson: GameState.fromJson,
  );
  final game = IdleGame<GameState>(
    config: IdleConfig<GameState>(dtMs: 1000),
    reducer: reducer,
    stateCodec: stateCodec,
  );

  final session = game.createSession(
    state: const GameState(gold: 0, rate: 1),
    lastSeenMs: 0,
  );

  session.engine.tick(count: 5);
  session.engine.dispatch(const UpgradeRate(2));
  session.engine.tick(count: 3);

  final nowMs = 10 * 1000;
  final offline = session.applyOffline(nowMs: nowMs);
  final saveJson = session.snapshotJson(game.saveCodec, nowMs: nowMs);

  stdout.writeln('Final: ${offline.state.toJson()}');
  stdout.writeln('Save JSON: $saveJson');
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

Persist a versioned save envelope with `IdleSaveCodec`:

```dart
final stateCodec = IdleStateCodec<GameState>(
  schemaVersion: 1,
  fromJson: GameState.fromJson,
);
final saveCodec = IdleSaveCodec<GameState>(stateCodec: stateCodec);

final saveJson = saveCodec.encodeState(
  state: engine.state,
  lastSeenMs: lastSeenMs,
);

final decoded = saveCodec.decode(saveJson);
final restoredEngine = IdleEngine<GameState>(
  config: IdleConfig<GameState>(dtMs: 1000),
  reducer: reducer,
  state: decoded.state,
);

final offline = restoredEngine.applyOfflineWindow(
  lastSeenMs: decoded.lastSeenMs,
  nowMs: nowMs,
);
```

## Versioned saves and migrations

Use `schemaVersion` and migrations to keep save data forward-compatible:

```dart
final codec = IdleStateCodec<GameState>(
  schemaVersion: 2,
  fromJson: GameState.fromJson,
  migrations: {
    0: (json) => <String, dynamic>{...json, 'rate': 1},
    1: (json) {
      final updated = Map<String, dynamic>.from(json);
      updated['gold'] = updated.remove('coins') ?? 0;
      return updated;
    },
  },
);
```

If a migration is missing, `IdleSaveCodec.decode` throws to avoid silent corruption.

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
- `IdleStateCodec` and `IdleSaveCodec` handle versioned save/load.
- `IdleSave` is the persisted state + last-seen snapshot.
- `IdleSession` keeps last-seen tracking safe while you tick.
- `IdleGame` bundles config, reducer, and codec for reuse.
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
