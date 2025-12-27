# idle_core

Deterministic idle game core engine SDK for Dart: fixed ticks, offline progress,
replay, and versioned saves. Pure Dart, no Flutter dependency.

**I am genuinely excited to release this updated version and finally hit the SDK-grade quality. 🚀✨**

## What you get

- Deterministic tick simulation and replay.
- First-class offline progress with caps and diagnostics.
- Version-safe saves with explicit migrations.
- Session helpers that keep `lastSeenMs` correct.

## Install

```yaml
dependencies:
  idle_core: ^0.3.1
```

## Minimal usage

```dart
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

GameState reducer(GameState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  return state;
}

void main() {
  final game = IdleGame<GameState>(
    config: IdleConfig<GameState>(dtMs: 1000),
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

  session.engine.tick(count: 5);
  final offline = session.applyOffline(nowMs: 10 * 1000);
  final saveJson = session.snapshotJson(game.saveCodec, nowMs: 10 * 1000);

  print(offline.state.toJson());
  print(saveJson);
}
```

## Offline flow (recommended)

```dart
final offline = session.applyOffline(nowMs: nowMs);
final saveJson = session.snapshotJson(game.saveCodec, nowMs: nowMs);
```

## Saves and migrations

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

## API snapshot

- `IdleEngine`, `IdleConfig`
- `IdleState`, `IdleReducer`
- `IdleStateCodec`, `IdleSave`, `IdleSaveCodec`
- `IdleSession`, `IdleGame`
- `TickClock`, `OfflineApplier`
- `TickResult`, `OfflineResult`
- `EventBus` (optional)

## Companion packages

- `idle_save` for storage adapters and encryption/signing.
- `idle_flutter` for Flutter lifecycle integration.

## Contact

If you find interest in collaborating/contribution or have questions, reach out at wonyoungchoiseoul@gmail.com.
