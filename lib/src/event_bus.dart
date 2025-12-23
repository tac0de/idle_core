/// Simple event collector for reducer-driven events.
class EventBus {
  final List<Object> _events = <Object>[];

  /// Creates an empty event bus.
  EventBus();

  /// Adds an [event] to the buffer.
  void emit(Object event) {
    _events.add(event);
  }

  /// Returns true when there are no buffered events.
  bool get isEmpty => _events.isEmpty;

  /// Returns buffered events and clears the buffer.
  List<Object> drain() {
    if (_events.isEmpty) {
      return const <Object>[];
    }
    final drained = List<Object>.unmodifiable(_events);
    _events.clear();
    return drained;
  }
}
