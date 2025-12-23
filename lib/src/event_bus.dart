class EventBus {
  final List<Object> _events = <Object>[];

  void emit(Object event) {
    _events.add(event);
  }

  bool get isEmpty => _events.isEmpty;

  List<Object> drain() {
    if (_events.isEmpty) {
      return const <Object>[];
    }
    final drained = List<Object>.unmodifiable(_events);
    _events.clear();
    return drained;
  }
}
