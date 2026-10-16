import 'package:flutter/material.dart';

import 'metronome_engine.dart';

class MetronomePage extends StatelessWidget {
  const MetronomePage({super.key, required this.engine});

  final MetronomeEngine engine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final theme = Theme.of(context);
        final displayBeat = engine.currentBeat;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '节拍器',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '基础节拍 · 强弱拍提示',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (engine.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '音频错误：${engine.lastError}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 60),
                  curve: Curves.easeOut,
                  height: 120,
                  decoration: BoxDecoration(
                    color: engine.running
                        ? (displayBeat == 1
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.5))
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      engine.running ? '$displayBeat' : '—',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: displayBeat == 1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= engine.beatsPerBar; i++) ...[
                      _BeatDot(
                        active: engine.running && displayBeat == i,
                        strong: i == 1,
                      ),
                      if (i < engine.beatsPerBar) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  '${engine.bpm} BPM',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => engine.setBpm(engine.bpm - 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Slider(
                        value: engine.bpm.toDouble(),
                        min: 40,
                        max: 208,
                        divisions: 168,
                        label: '${engine.bpm}',
                        onChanged: (v) => engine.setBpm(v.round()),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => engine.setBpm(engine.bpm + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('拍号', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('2/4')),
                    ButtonSegment(value: 3, label: Text('3/4')),
                    ButtonSegment(value: 4, label: Text('4/4')),
                  ],
                  selected: {engine.beatsPerBar},
                  onSelectionChanged: (s) => engine.setBeatsPerBar(s.first),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    if (engine.running) {
                      await engine.stop();
                    } else {
                      await engine.start();
                    }
                  },
                  icon: Icon(engine.running ? Icons.stop : Icons.play_arrow),
                  label: Text(engine.running ? '停止' : '开始'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BeatDot extends StatelessWidget {
  const _BeatDot({required this.active, required this.strong});

  final bool active;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: active ? 22 : 14,
      height: active ? 22 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withValues(alpha: 0.25),
      ),
    );
  }
}
