import 'event_bus.dart';
import 'state.dart';

typedef ResourceDelta<S extends IdleState> = Map<String, num> Function(
  S before,
  S after,
);

class IdleConfig<S extends IdleState> {
  final int dtMs;
  final int maxOfflineMs;
  final int maxTicksTotal;
  final int maxTicksPerChunk;
  final ResourceDelta<S>? resourceDelta;
  final EventBus? eventBus;

  IdleConfig({
    this.dtMs = 1000,
    this.maxOfflineMs = 1000 * 60 * 60 * 24,
    this.maxTicksTotal = 100000,
    this.maxTicksPerChunk = 1000,
    this.resourceDelta,
    this.eventBus,
  }) {
    if (dtMs <= 0) {
      throw ArgumentError.value(dtMs, 'dtMs', 'Must be > 0');
    }
    if (maxOfflineMs < 0) {
      throw ArgumentError.value(maxOfflineMs, 'maxOfflineMs', 'Must be >= 0');
    }
    if (maxTicksTotal < 0) {
      throw ArgumentError.value(maxTicksTotal, 'maxTicksTotal', 'Must be >= 0');
    }
    if (maxTicksPerChunk <= 0) {
      throw ArgumentError.value(
        maxTicksPerChunk,
        'maxTicksPerChunk',
        'Must be > 0',
      );
    }
  }
}
