# idle_core

Core, pure-Dart runtime for idle game development with deterministic ticks,
offline progress, and replay-friendly reducers.

## Quick start

Add the dependency:

```yaml
dependencies:
  idle_core: ^0.1.0
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

  final offline = engine.applyOffline(0, 10 * 1000);
  stdout.writeln('Final: ${offline.state.toJson()}');
}
```

## Demo

Screenshot:

![idle_core demo](docs/images/demo1.png)
![idle_core_demo](docs/images/demo2.png)

To create the screenshot, run the Flutter demo in `demo/` and capture the UI.

## Why idle_core

idle_core is a deterministic, pure-Dart runtime for idle game logic.
It is not an inactivity detector or platform plugin.

- Deterministic tick simulation and offline progress
- Replay-friendly reducers for save/load and debugging
- Pure Dart core (no Flutter dependency)
- Safety caps and chunking for large offline windows

Comparison:

| Feature              | idle_core | idle detector packages |
| -------------------- | --------- | ---------------------- |
| Offline simulation   | Yes       | No                     |
| Deterministic replay | Yes       | No                     |
| Pure Dart runtime    | Yes       | No                     |
| Inactivity detection | No        | Yes                    |

## Docs

- `docs/guide.md` for determinism and offline rules.

## API overview

- `IdleEngine` orchestrates ticks and offline application.
- `IdleConfig` defines time step and safety caps.
- `IdleState` is immutable and JSON-serializable.
- `IdleReducer` is a pure function `(state, action) -> state`.
- `TickClock` is injectable for tests.
- `TickResult` and `OfflineResult` summarize progress.
- `EventBus` optionally collects events for result snapshots.
- Helpers: `tickForDuration`, `applyOfflineFromClock`, `replay`, `advance`.

## Core concepts

State and reducer:

- State is immutable and JSON-serializable.
- Reducer is pure and deterministic.
- Tick logic is driven by `IdleTickAction(dtMs)`.

Determinism rules:

- No `DateTime.now()` inside the reducer.
- No randomness without a seeded PRNG passed through state.

## Offline progress

```dart
final result = engine.applyOffline(lastSeenMs, nowMs);
```

Offline processing:

- `delta = clamp(now - lastSeen, 0, maxOfflineMs)`
- `ticks = floor(delta / dtMs)` then capped by `maxTicksTotal`
- Work is chunked by `maxTicksPerChunk`

## Configuration

`IdleConfig` fields:

- `dtMs`: fixed tick size in milliseconds (default 1000)
- `maxOfflineMs`: maximum offline window
- `maxTicksTotal`: hard cap on total ticks applied
- `maxTicksPerChunk`: chunk size for offline work
- `resourceDelta`: optional `(before, after) -> Map<String, num>`
- `eventBus`: optional `EventBus` to collect events

## Results

`TickResult` and `OfflineResult` include:

- `ticksApplied`
- `resourcesDelta` (if provided)
- `events` (if `EventBus` is used)

`OfflineResult` also includes:

- `requestedDeltaMs`, `clampedDeltaMs`, `appliedDeltaMs`
- `ticksRequested`, `ticksCapped`, `chunks`
