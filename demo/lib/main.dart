import 'package:flutter/material.dart';
import 'package:idle_core/idle_core.dart';

/// Simple economy state for the demo.
class EconomyState extends IdleState {
  /// Current gold amount.
  final int gold;

  /// Gold earned per tick.
  final int rate;

  /// Creates a new economy state.
  const EconomyState({required this.gold, required this.rate});

  /// Returns a copy with updated values.
  EconomyState copyWith({int? gold, int? rate}) {
    return EconomyState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

  /// Converts state to JSON.
  @override
  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};
}

/// Action that increases the gold rate.
class UpgradeRate extends IdleAction {
  /// Amount to add to the rate.
  final int delta;

  /// Creates an upgrade action.
  const UpgradeRate(this.delta);
}

/// Reducer for the demo economy.
EconomyState reducer(EconomyState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

/// Entry point for the demo app.
void main() {
  runApp(const IdleCoreDemoApp());
}

/// Root widget for the demo app.
class IdleCoreDemoApp extends StatelessWidget {
  /// Creates the demo app widget.
  const IdleCoreDemoApp({super.key});

  /// Builds the MaterialApp for the demo.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'idle_core demo',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DemoHomePage(),
    );
  }
}

/// Home page displaying demo controls and results.
class DemoHomePage extends StatefulWidget {
  /// Creates the demo home page.
  const DemoHomePage({super.key});

  /// Creates the state for the demo home page.
  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  late final IdleEngine<EconomyState> _engine;
  late final IdleConfig<EconomyState> _config;
  TickResult<EconomyState>? _lastTick;
  OfflineResult<EconomyState>? _lastOffline;
  String _lastAction = 'None';

  static const int _offlineFiveMinutesMs = 5 * 60 * 1000;

  @override
  void initState() {
    super.initState();
    _config = IdleConfig<EconomyState>(
      dtMs: 1000,
      maxOfflineMs: 1000 * 60 * 60 * 8,
      maxTicksTotal: 10000,
      maxTicksPerChunk: 200,
      resourceDelta: (before, after) => {
        'gold': after.gold - before.gold,
      },
    );
    _engine = IdleEngine<EconomyState>(
      config: _config,
      reducer: reducer,
      state: const EconomyState(gold: 0, rate: 1),
    );
  }

  void _setAction(String label) {
    _lastAction = label;
  }

  void _tick() {
    setState(() {
      _lastTick = _engine.tick();
      _setAction('Tick +1');
    });
  }

  void _tickBatch() {
    setState(() {
      _lastTick = _engine.tick(count: 10);
      _setAction('Tick +10');
    });
  }

  void _upgrade() {
    setState(() {
      _lastTick = _engine.dispatch(const UpgradeRate(1));
      _setAction('Upgrade +1');
    });
  }

  void _offlineFiveMinutes() {
    setState(() {
      _lastOffline = _engine.applyOffline(0, _offlineFiveMinutesMs);
      _setAction('Offline 5m');
    });
  }

  void _tickForDuration() {
    setState(() {
      _lastTick = _engine.tickForDuration(2500);
      _setAction('Tick for 2500ms');
    });
  }

  void _replayDemo() {
    setState(() {
      _lastTick = _engine.replay(<IdleAction>[
        const IdleTickAction(1000),
        const IdleTickAction(1000),
        const UpgradeRate(2),
        const IdleTickAction(1000),
      ]);
      _setAction('Replay demo actions');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    final lastTick = _lastTick;
    final lastOffline = _lastOffline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('idle_core demo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What this demo shows',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                '1) Each tick adds rate to gold (IdleTickAction).\n'
                '2) Upgrade changes rate (IdleAction).\n'
                '3) Offline sim fast-forwards with caps and chunking.\n'
                '4) Replay applies a deterministic action list.\n'
                '5) resourceDelta summarizes changes per action.',
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current state',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Gold: ${state.gold}'),
                      Text('Rate: ${state.rate} / tick'),
                      const SizedBox(height: 12),
                      Text('Config',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('dtMs: ${_config.dtMs}'),
                      Text('maxOfflineMs: ${_config.maxOfflineMs}'),
                      Text('maxTicksTotal: ${_config.maxTicksTotal}'),
                      Text('maxTicksPerChunk: ${_config.maxTicksPerChunk}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Actions',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton(
                              onPressed: _tick,
                              child: const Text('Tick +1')),
                          ElevatedButton(
                              onPressed: _tickBatch,
                              child: const Text('Tick +10')),
                          ElevatedButton(
                              onPressed: _tickForDuration,
                              child: const Text('Tick for 2500ms')),
                          ElevatedButton(
                              onPressed: _upgrade,
                              child: const Text('Upgrade +1')),
                          ElevatedButton(
                            onPressed: _offlineFiveMinutes,
                            child: const Text('Offline 5m'),
                          ),
                          ElevatedButton(
                              onPressed: _replayDemo,
                              child: const Text('Replay demo')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last action: $_lastAction',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text('Last tick result',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text('Ticks applied: ${lastTick?.ticksApplied ?? 0}'),
                      Text('Resources delta: ${lastTick?.resourcesDelta ?? {}}'),
                      const SizedBox(height: 16),
                      Text('Last offline result',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text('Ticks applied: ${lastOffline?.ticksApplied ?? 0}'),
                      Text('Chunks: ${lastOffline?.chunks ?? 0}'),
                      Text('Requested ms: ${lastOffline?.requestedDeltaMs ?? 0}'),
                      Text('Clamped ms: ${lastOffline?.clampedDeltaMs ?? 0}'),
                      Text('Applied ms: ${lastOffline?.appliedDeltaMs ?? 0}'),
                      Text('Was clamped: ${lastOffline?.wasClamped ?? false}'),
                      Text('Was capped: ${lastOffline?.wasCapped ?? false}'),
                      Text('Resources delta: ${lastOffline?.resourcesDelta ?? {}}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
