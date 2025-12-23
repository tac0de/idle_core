abstract class IdleAction {
  const IdleAction();
}

class IdleTickAction extends IdleAction {
  final int dtMs;

  const IdleTickAction(this.dtMs);
}
