import 'actions.dart';

/// Base class for immutable, JSON-serializable simulation state.
abstract class SimulationState {
  /// Creates a state instance.
  const SimulationState();

  /// Converts the state into a JSON-compatible map.
  Map<String, dynamic> toJson();
}

/// Pure reducer that maps a [state] and [action] to a new state.
typedef SimulationReducer<S extends SimulationState> = S Function(
  S state,
  SimulationAction action,
);
