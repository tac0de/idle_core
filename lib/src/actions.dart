/// Base class for actions processed by an [IdleReducer].
abstract class IdleAction {
  /// Creates an action instance.
  const IdleAction();
}

/// Action dispatched for each simulated tick.
class IdleTickAction extends IdleAction {
  /// Tick duration in milliseconds.
  final int dtMs;

  /// Creates a tick action with the given [dtMs].
  const IdleTickAction(this.dtMs);
}
