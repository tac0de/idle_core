import 'package:idle_core/idle_core.dart';
import 'package:test/test.dart';

class _VersionedState extends IdleState {
  final int gold;
  final int rate;

  const _VersionedState({required this.gold, required this.rate});

  factory _VersionedState.fromJson(Map<String, dynamic> json) {
    return _VersionedState(
      gold: json['gold'] as int,
      rate: json['rate'] as int,
    );
  }

  _VersionedState copyWith({int? gold, int? rate}) {
    return _VersionedState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};
}

_VersionedState _reducer(_VersionedState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  return state;
}

void main() {
  test('save codec migrates older schemas', () {
    final codec = IdleStateCodec<_VersionedState>(
      schemaVersion: 2,
      fromJson: _VersionedState.fromJson,
      migrations: {
        0: (json) {
          final updated = Map<String, dynamic>.from(json);
          updated['gold'] = updated.remove('coins') ?? 0;
          return updated;
        },
        1: (json) => <String, dynamic>{
              ...json,
              'rate': json['rate'] ?? 1,
            },
      },
    );
    final saveCodec = IdleSaveCodec<_VersionedState>(stateCodec: codec);

    final decoded = saveCodec.decode(<String, dynamic>{
      'schemaVersion': 0,
      'lastSeenMs': 500,
      'state': <String, dynamic>{'coins': 5},
    });

    expect(decoded.schemaVersion, equals(2));
    expect(decoded.state.gold, equals(5));
    expect(decoded.state.rate, equals(1));
    expect(decoded.lastSeenMs, equals(500));
  });

  test('save codec requires lastSeenMs unless provided', () {
    final codec = IdleStateCodec<_VersionedState>(
      schemaVersion: 0,
      fromJson: _VersionedState.fromJson,
    );
    final saveCodec = IdleSaveCodec<_VersionedState>(stateCodec: codec);

    expect(
      () => saveCodec.decode(<String, dynamic>{
        'schemaVersion': 0,
        'state': <String, dynamic>{'gold': 1, 'rate': 1},
      }),
      throwsFormatException,
    );

    final decoded = saveCodec.decode(
      <String, dynamic>{
        'schemaVersion': 0,
        'state': <String, dynamic>{'gold': 2, 'rate': 1},
      },
      fallbackLastSeenMs: 1234,
    );
    expect(decoded.lastSeenMs, equals(1234));
  });

  test('save codec throws when migration is missing', () {
    final codec = IdleStateCodec<_VersionedState>(
      schemaVersion: 1,
      fromJson: _VersionedState.fromJson,
    );
    final saveCodec = IdleSaveCodec<_VersionedState>(stateCodec: codec);

    expect(
      () => saveCodec.decode(<String, dynamic>{
        'schemaVersion': 0,
        'lastSeenMs': 0,
        'state': <String, dynamic>{'gold': 1, 'rate': 1},
      }),
      throwsA(isA<StateError>()),
    );
  });

  test('session applies offline and updates last-seen', () {
    final clock = ManualTickClock(5000);
    final engine = IdleEngine<_VersionedState>(
      config: IdleConfig<_VersionedState>(dtMs: 1000),
      reducer: _reducer,
      state: const _VersionedState(gold: 0, rate: 1),
      clock: clock,
    );
    final session = IdleSession<_VersionedState>(
      engine: engine,
      lastSeenMs: 0,
    );

    final result = session.applyOffline();
    expect(result.ticksApplied, equals(5));
    expect(result.state.gold, equals(5));
    expect(session.lastSeenMs, equals(5000));
  });

  test('session snapshot updates last-seen and schema version', () {
    final clock = ManualTickClock(1000);
    final engine = IdleEngine<_VersionedState>(
      config: IdleConfig<_VersionedState>(dtMs: 1000),
      reducer: _reducer,
      state: const _VersionedState(gold: 3, rate: 1),
      clock: clock,
    );
    final session = IdleSession<_VersionedState>(
      engine: engine,
      lastSeenMs: 0,
    );
    final codec = IdleSaveCodec<_VersionedState>(
      stateCodec: IdleStateCodec<_VersionedState>(
        schemaVersion: 2,
        fromJson: _VersionedState.fromJson,
      ),
    );

    final snapshot = session.snapshot(codec, nowMs: 2500);
    expect(snapshot.lastSeenMs, equals(2500));
    expect(snapshot.schemaVersion, equals(2));
    expect(session.lastSeenMs, equals(2500));
  });
}
