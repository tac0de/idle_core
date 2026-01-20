/// Base class for actions processed by a [SimulationReducer].
abstract class SimulationAction {
  /// Creates an action instance.
  const SimulationAction();
}

/// Action dispatched for each simulated tick.
class TickAction extends SimulationAction {
  /// Tick duration in milliseconds.
  final int dtMs;

  /// Creates a tick action with the given [dtMs].
  const TickAction(this.dtMs);
}
