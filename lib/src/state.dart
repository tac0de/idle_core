import 'actions.dart';

/// Base class for immutable, JSON-serializable game state.
abstract class IdleState {
  /// Creates a state instance.
  const IdleState();

  /// Converts the state into a JSON-compatible map.
  Map<String, dynamic> toJson();
}

/// Pure reducer that maps a [state] and [action] to a new state.
typedef IdleReducer<S extends IdleState> = S Function(
  S state,
  IdleAction action,
);
