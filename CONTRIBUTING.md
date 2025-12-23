# Contributing

Thanks for your interest in improving idle_core!

## Development setup

- Install Dart SDK (stable).
- Run:

```sh
dart pub get
dart analyze
dart test
```

## Project goals

- Deterministic tick simulation.
- No Flutter or platform dependencies.
- Pure functions for reducers.
- Offline progress with strict caps.

## Guidelines

- Keep public APIs in `lib/idle_core.dart`.
- Avoid `DateTime.now()` in reducers; pass time in actions/state.
- Prefer immutable state with `copyWith`.
- Include tests for behavior changes.

## Tests

- Add unit tests to `test/` for new behavior.
- Keep snapshots JSON-based and stable.

## Style

- Follow `analysis_options.yaml` and `dart format`.
- Avoid `print` in library code.
