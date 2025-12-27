import 'state.dart';

/// Decodes JSON into a typed [IdleState].
typedef IdleStateDecoder<S extends IdleState> = S Function(
  Map<String, dynamic> json,
);

/// Encodes a typed [IdleState] to JSON.
typedef IdleStateEncoder<S extends IdleState> = Map<String, dynamic> Function(
  S state,
);

/// Migrates JSON from one schema version to the next.
typedef IdleStateMigration = Map<String, dynamic> Function(
  Map<String, dynamic> json,
);

Map<String, dynamic> _defaultStateEncoder<S extends IdleState>(S state) {
  return state.toJson();
}

/// Codec describing how to encode, decode, and migrate state versions.
class IdleStateCodec<S extends IdleState> {
  /// Current schema version.
  final int schemaVersion;

  /// Decoder for the latest schema version.
  final IdleStateDecoder<S> fromJson;

  /// Encoder for the latest schema version.
  final IdleStateEncoder<S> toJson;

  /// Migrations keyed by the source version (to source + 1).
  final Map<int, IdleStateMigration> migrations;

  /// Creates a codec with optional migrations.
  IdleStateCodec({
    required this.schemaVersion,
    required this.fromJson,
    IdleStateEncoder<S>? toJson,
    Map<int, IdleStateMigration>? migrations,
  })  : toJson = toJson ?? _defaultStateEncoder,
        migrations = migrations ?? const <int, IdleStateMigration>{} {
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
        'Save schema $fromVersion is newer than codec $schemaVersion.',
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

/// Snapshot of state and last-seen time used for persistence.
class IdleSave<S extends IdleState> {
  /// State at save time.
  final S state;

  /// Last time the player was seen (ms since epoch).
  final int lastSeenMs;

  /// Schema version used to encode the state.
  final int schemaVersion;

  /// Creates a save snapshot.
  const IdleSave({
    required this.state,
    required this.lastSeenMs,
    required this.schemaVersion,
  });
}

/// JSON encoder/decoder for [IdleSave] snapshots.
class IdleSaveCodec<S extends IdleState> {
  /// State codec used for migrations and typed decoding.
  final IdleStateCodec<S> stateCodec;

  /// Key for schema version in the save JSON.
  final String schemaVersionKey;

  /// Key for last-seen timestamp in the save JSON.
  final String lastSeenMsKey;

  /// Key for state JSON in the save JSON.
  final String stateKey;

  /// Creates a save codec with JSON keys.
  const IdleSaveCodec({
    required this.stateCodec,
    this.schemaVersionKey = 'schemaVersion',
    this.lastSeenMsKey = 'lastSeenMs',
    this.stateKey = 'state',
  });

  /// Captures a typed save snapshot.
  IdleSave<S> capture({required S state, required int lastSeenMs}) {
    if (lastSeenMs < 0) {
      throw ArgumentError.value(lastSeenMs, 'lastSeenMs', 'Must be >= 0');
    }
    return IdleSave<S>(
      state: state,
      lastSeenMs: lastSeenMs,
      schemaVersion: stateCodec.schemaVersion,
    );
  }

  /// Encodes a typed save snapshot to JSON.
  Map<String, dynamic> encode(IdleSave<S> save) {
    return <String, dynamic>{
      schemaVersionKey: save.schemaVersion,
      lastSeenMsKey: save.lastSeenMs,
      stateKey: stateCodec.toJson(save.state),
    };
  }

  /// Encodes a state + last-seen into JSON for persistence.
  Map<String, dynamic> encodeState({
    required S state,
    required int lastSeenMs,
  }) {
    return encode(capture(state: state, lastSeenMs: lastSeenMs));
  }

  /// Decodes JSON into a typed save snapshot, migrating as needed.
  IdleSave<S> decode(
    Map<String, dynamic> json, {
    int? fallbackLastSeenMs,
  }) {
    final rawVersion = json[schemaVersionKey];
    final version = rawVersion is int ? rawVersion : 0;
    if (version < 0) {
      throw const FormatException('schemaVersion must be >= 0.');
    }
    final rawLastSeenMs = json[lastSeenMsKey];
    final lastSeenMs =
        rawLastSeenMs is int ? rawLastSeenMs : fallbackLastSeenMs;
    if (lastSeenMs == null) {
      throw FormatException('Missing or invalid $lastSeenMsKey.');
    }
    final rawState = json[stateKey];
    if (rawState is! Map) {
      throw FormatException('Missing or invalid $stateKey.');
    }
    final stateJson = Map<String, dynamic>.from(rawState);
    final migrated = stateCodec.migrate(stateJson, version);
    final state = stateCodec.fromJson(migrated);
    return IdleSave<S>(
      state: state,
      lastSeenMs: lastSeenMs,
      schemaVersion: stateCodec.schemaVersion,
    );
  }
}
