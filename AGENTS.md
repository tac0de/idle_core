# AGENTS.md (gpt-5.2-codex-max) — idle_core (Pure Dart)

## Goal

Create a pure-Dart “idle core” engine: tick simulation + offline progress + deterministic replay. No Flutter deps.

## Repo

pkg: `idle_core`
dirs: `lib/`, `test/`, `example/`, `tool/`

## Public API (lib/idle_core.dart)

Exports:

- `IdleEngine`, `IdleConfig`
- `IdleState` (immutable), `IdleReducer`
- `TickClock`, `OfflineApplier`
- `TickResult`, `OfflineResult`
- `EventBus` (optional)

## Core Concepts

- **State**: immutable (copyWith). Must be JSON-serializable.
- **Reducer**: pure function `(IdleState s, IdleAction a) -> IdleState`
- **Tick**: fixed step `dtMs` (default 1000ms). Deterministic.
- **Offline**: fast-forward from `lastSeen` to `now` using chunking + caps.

## Requirements

1. Determinism: same inputs => same outputs (no DateTime.now inside reducer).
2. Performance: offline up to N hours; simulate in chunks.
3. Safety: caps: `maxOfflineMs`, `maxTicksTotal`, `maxTicksPerChunk`.
4. Extensibility: user provides reducer + initial state + optional hooks.

## Data Models

- `IdleConfig{dtMs,maxOfflineMs,maxTicksTotal,maxTicksPerChunk}`
- `IdleEngine{config,reducer,state,clock}`
- `TickClock` provides `nowMs()` (injectable for tests).
- Results include: `ticksApplied`, `resourcesDelta`, `events[]` (optional).

## Offline Algorithm

Input: `lastSeenMs, nowMs`

1. `delta=clamp(now-lastSeen,0,maxOfflineMs)`
2. `ticks=floor(delta/dtMs)`; clamp to `maxTicksTotal`
3. loop chunks of `maxTicksPerChunk`: apply `tick()` repeatedly
4. return `OfflineResult` with summary + final state.

## Tasks (Implement in order)

T1. Package scaffold + strict analysis options.
T2. Define models + reducer/action interfaces.
T3. Implement `IdleEngine.tick(count=1)` and `step(dtMs)`.
T4. Implement `applyOffline(lastSeenMs, nowMs)`.
T5. Add unit tests: determinism, caps, chunking, edge cases (0/negative delta).
T6. Add example: minimal idle economy (gold += rate; upgrade changes rate).

## Testing Rules

- Use fake clock, fixed seeds.
- Snapshot JSON of final state for known scenarios.
- Property test: `applyOffline(a,b)` == repeated ticks.

## Done Criteria

- `dart test` green
- `example/` runnable
- API docs in README (brief)
