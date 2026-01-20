import 'state.dart';

/// Decodes JSON into a typed [SimulationState].
typedef StateDecoder<S extends SimulationState> = S Function(
  Map<String, dynamic> json,
);

/// Encodes a typed [SimulationState] to JSON.
typedef StateEncoder<S extends SimulationState> = Map<String, dynamic> Function(
  S state,
);

/// Migrates JSON from one schema version to the next.
typedef StateMigration = Map<String, dynamic> Function(
  Map<String, dynamic> json,
);

Map<String, dynamic> _defaultStateEncoder<S extends SimulationState>(S state) {
  return state.toJson();
}

/// Codec describing how to encode, decode, and migrate state versions.
class StateCodec<S extends SimulationState> {
  /// Current schema version.
  final int schemaVersion;

  /// Decoder for the latest schema version.
  final StateDecoder<S> fromJson;

  /// Encoder for the latest schema version.
  final StateEncoder<S> toJson;

  /// Migrations keyed by the source version (to source + 1).
  final Map<int, StateMigration> migrations;

  /// Creates a codec with optional migrations.
  StateCodec({
    required this.schemaVersion,
    required this.fromJson,
    StateEncoder<S>? toJson,
    Map<int, StateMigration>? migrations,
  })  : toJson = toJson ?? _defaultStateEncoder,
        migrations = migrations ?? const <int, StateMigration>{} {
    if (schemaVersion < 0) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Must be >= 0',
      );
    }
  }

  /// Applies migrations to move [json] from [fromVersion] to [schemaVersion].
  Map<String, dynamic> migrate(Map<String, dynamic> json, int fromVersion) {
    if (fromVersion < 0) {
      throw ArgumentError.value(fromVersion, 'fromVersion', 'Must be >= 0');
    }
    if (fromVersion > schemaVersion) {
      throw StateError(
        'Snapshot schema $fromVersion is newer than codec $schemaVersion.',
      );
    }
    var current = Map<String, dynamic>.from(json);
    var version = fromVersion;
    while (version < schemaVersion) {
      final migrator = migrations[version];
      if (migrator == null) {
        throw StateError(
          'Missing migration from $version to ${version + 1}.',
        );
      }
      current = Map<String, dynamic>.from(migrator(current));
      version += 1;
    }
    return current;
  }
}

/// Snapshot of state and last-observed time used for persistence.
class Snapshot<S extends SimulationState> {
  /// State at snapshot time.
  final S state;

  /// Last time the state was observed (ms since epoch).
  final int lastObservedMs;

  /// Schema version used to encode the state.
  final int schemaVersion;

  /// Creates a snapshot.
  const Snapshot({
    required this.state,
    required this.lastObservedMs,
    required this.schemaVersion,
  });
}

/// JSON encoder/decoder for [Snapshot] snapshots.
class SnapshotCodec<S extends SimulationState> {
  /// State codec used for migrations and typed decoding.
  final StateCodec<S> stateCodec;

  /// Key for schema version in the snapshot JSON.
  final String schemaVersionKey;

  /// Key for last-observed timestamp in the snapshot JSON.
  final String lastObservedMsKey;

  /// Key for state JSON in the snapshot JSON.
  final String stateKey;

  /// Creates a snapshot codec with JSON keys.
  const SnapshotCodec({
    required this.stateCodec,
    this.schemaVersionKey = 'schemaVersion',
    this.lastObservedMsKey = 'lastObservedMs',
    this.stateKey = 'state',
  });

  /// Captures a typed snapshot.
  Snapshot<S> capture({required S state, required int lastObservedMs}) {
    if (lastObservedMs < 0) {
      throw ArgumentError.value(lastObservedMs, 'lastObservedMs', 'Must be >= 0');
    }
    return Snapshot<S>(
      state: state,
      lastObservedMs: lastObservedMs,
      schemaVersion: stateCodec.schemaVersion,
    );
  }

  /// Encodes a typed snapshot to JSON.
  Map<String, dynamic> encode(Snapshot<S> snapshot) {
    return <String, dynamic>{
      schemaVersionKey: snapshot.schemaVersion,
      lastObservedMsKey: snapshot.lastObservedMs,
      stateKey: stateCodec.toJson(snapshot.state),
    };
  }

  /// Encodes a state + last-observed timestamp into JSON for persistence.
  Map<String, dynamic> encodeState({
    required S state,
    required int lastObservedMs,
  }) {
    return encode(capture(state: state, lastObservedMs: lastObservedMs));
  }

  /// Decodes JSON into a typed snapshot, migrating as needed.
  Snapshot<S> decode(
    Map<String, dynamic> json, {
    int? fallbackLastObservedMs,
  }) {
    final rawVersion = json[schemaVersionKey];
    final version = rawVersion is int ? rawVersion : 0;
    if (version < 0) {
      throw const FormatException('schemaVersion must be >= 0.');
    }
    final rawLastObservedMs = json[lastObservedMsKey];
    final lastObservedMs =
        rawLastObservedMs is int ? rawLastObservedMs : fallbackLastObservedMs;
    if (lastObservedMs == null) {
      throw FormatException('Missing or invalid $lastObservedMsKey.');
    }
    final rawState = json[stateKey];
    if (rawState is! Map) {
      throw FormatException('Missing or invalid $stateKey.');
    }
    final stateJson = Map<String, dynamic>.from(rawState);
    final migrated = stateCodec.migrate(stateJson, version);
    final state = stateCodec.fromJson(migrated);
    return Snapshot<S>(
      state: state,
      lastObservedMs: lastObservedMs,
      schemaVersion: stateCodec.schemaVersion,
    );
  }
}
