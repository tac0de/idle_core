# idle_core guide

## Overview

idle_core provides a deterministic tick engine with offline progress. You supply:

- A state object (immutable, JSON-serializable).
- A reducer function that applies actions to state.

## Determinism checklist

- Do not call `DateTime.now()` inside reducers.
- Do not use randomness unless the seed is stored in state.
- Only mutate state via returned copies.

## Tick flow

- `IdleEngine.tick(count)` applies `IdleTickAction(dtMs)` repeatedly.
- `IdleEngine.step(dtMs, count)` uses a custom dt.
- `IdleEngine.dispatch(action)` applies a non-tick action.
- `IdleEngine.tickForDuration(deltaMs)` converts a duration to ticks.
- `IdleEngine.replay(actions)` replays a deterministic action list.

## Offline flow

`applyOffline(lastSeenMs, nowMs)`:

1) Clamp delta to `[0, maxOfflineMs]`
2) Convert to ticks with `floor(delta / dtMs)`
3) Cap total ticks with `maxTicksTotal`
4) Apply in chunks of `maxTicksPerChunk`

Use `OfflineResult` to inspect how many ticks were applied and whether caps were hit.

Convenience methods:

- `applyOfflineFromClock(lastSeenMs)` uses the injected clock.
- `advance(nowMs, lastSeenMs)` is an alias to simplify resume logic.

Helper functions:

- `clampOfflineDeltaMs(requestedDeltaMs, maxOfflineMs)`
- `calcTicksForDelta(deltaMs, dtMs)`

## Resource delta

Provide a `resourceDelta` function in `IdleConfig` to compute a summary delta:

```dart
final config = IdleConfig<MyState>(
  resourceDelta: (before, after) => {
    'gold': after.gold - before.gold,
  },
);
```

## Event bus

Use `EventBus` to collect events during reducers and read them from results:

```dart
final bus = EventBus();
final config = IdleConfig<MyState>(eventBus: bus);

bus.emit(MyEvent());
```

`TickResult.events` and `OfflineResult.events` contain drained events.
