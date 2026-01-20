import 'package:idle_core/idle_core.dart';
import 'package:test/test.dart';

class _VersionedState extends SimulationState {
  final int counter;
  final int rate;

  const _VersionedState({required this.counter, required this.rate});

  factory _VersionedState.fromJson(Map<String, dynamic> json) {
    return _VersionedState(
      counter: json['counter'] as int,
      rate: json['rate'] as int,
    );
  }

  _VersionedState copyWith({int? counter, int? rate}) {
    return _VersionedState(
      counter: counter ?? this.counter,
      rate: rate ?? this.rate,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'counter': counter, 'rate': rate};
}

void main() {
  test('snapshot codec migrates older schemas', () {
    final codec = StateCodec<_VersionedState>(
      schemaVersion: 2,
      fromJson: _VersionedState.fromJson,
      migrations: {
        0: (json) {
          final updated = Map<String, dynamic>.from(json);
          updated['counter'] = updated.remove('count') ?? 0;
          return updated;
        },
        1: (json) => <String, dynamic>{
              ...json,
              'rate': json['rate'] ?? 1,
            },
      },
    );
    final snapshotCodec = SnapshotCodec<_VersionedState>(stateCodec: codec);

    final decoded = snapshotCodec.decode(<String, dynamic>{
      'schemaVersion': 0,
      'lastObservedMs': 500,
      'state': <String, dynamic>{'count': 5},
    });

    expect(decoded.schemaVersion, equals(2));
    expect(decoded.state.counter, equals(5));
    expect(decoded.state.rate, equals(1));
    expect(decoded.lastObservedMs, equals(500));
  });

  test('snapshot codec requires lastObservedMs unless provided', () {
    final codec = StateCodec<_VersionedState>(
      schemaVersion: 0,
      fromJson: _VersionedState.fromJson,
    );
    final snapshotCodec = SnapshotCodec<_VersionedState>(stateCodec: codec);

    expect(
      () => snapshotCodec.decode(<String, dynamic>{
        'schemaVersion': 0,
        'state': <String, dynamic>{'counter': 1, 'rate': 1},
      }),
      throwsFormatException,
    );

    final decoded = snapshotCodec.decode(
      <String, dynamic>{
        'schemaVersion': 0,
        'state': <String, dynamic>{'counter': 2, 'rate': 1},
      },
      fallbackLastObservedMs: 1234,
    );
    expect(decoded.lastObservedMs, equals(1234));
  });

  test('snapshot codec throws when migration is missing', () {
    final codec = StateCodec<_VersionedState>(
      schemaVersion: 1,
      fromJson: _VersionedState.fromJson,
    );
    final snapshotCodec = SnapshotCodec<_VersionedState>(stateCodec: codec);

    expect(
      () => snapshotCodec.decode(<String, dynamic>{
        'schemaVersion': 0,
        'lastObservedMs': 0,
        'state': <String, dynamic>{'counter': 1, 'rate': 1},
      }),
      throwsA(isA<StateError>()),
    );
  });

  test('snapshot capture records schema version and lastObservedMs', () {
    final codec = SnapshotCodec<_VersionedState>(
      stateCodec: StateCodec<_VersionedState>(
        schemaVersion: 2,
        fromJson: _VersionedState.fromJson,
      ),
    );

    final snapshot = codec.capture(
      state: const _VersionedState(counter: 3, rate: 1),
      lastObservedMs: 2500,
    );
    expect(snapshot.lastObservedMs, equals(2500));
    expect(snapshot.schemaVersion, equals(2));
  });
}
