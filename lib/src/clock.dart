abstract class TickClock {
  int nowMs();
}

class SystemTickClock implements TickClock {
  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}
