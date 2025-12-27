# Changelog

## 0.3.0

- Add save/versioning helpers with `IdleStateCodec` and `IdleSaveCodec`.
- Add `IdleSession` and `IdleGame` to reduce boilerplate and prevent last-seen mistakes.
- Document recommended SDK flow with migrations and save snapshots.

## 0.2.2

- Deprecate the `advance` alias to prevent argument-order mistakes.
- Add integration contract and UpgradeRate snippet to README.

## 0.2.1

- Use UpgradeRate in determinism tool and document its usage.
- Remove doc folder and move guidance into README.
- Strengthen determinism tool with replay and upgrade actions.
- Remove non-core save/load and RNG demos from idle_core.
- Clarify companion packages and narrow docs to core usage.
- Add save/load and deterministic RNG demos.
- Add determinism check tool script.
- Remove Flutter demo assets to keep package pure Dart focused.
- Expand README/guide with save/load and RNG recipes.
- Expand README and guide with capability demos.
- Add replay demo example showcasing deterministic replay and caps.
- Add manual clock for tests and replays.
- Add offline diagnostics for leftover time and backwards clocks.
- Expand README/guide/example to highlight safe offline patterns.
- Add named-parameter offline helper and last-seen helper.
- Expand docs with safer offline usage tips.

## 0.1.2

- Documentation update.

## 0.1.1

- Documentation update.

## 0.1.0

- Initial release with deterministic tick engine and offline progress.
