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
                        ? (engine.isAccent(displayBeat)
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
                        color: engine.isAccent(displayBeat)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      for (var i = 1; i <= engine.beatsPerBar; i++)
                        Expanded(
                          child: _BeatDot(
                            active: engine.running && displayBeat == i,
                            strong: engine.isAccent(i),
                            onTap: () => engine.toggleAccent(i),
                          ),
                        ),
                    ],
                  ),
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
                        min: 20,
                        max: 250,
                        divisions: 230,
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
                const SizedBox(height: 16),
                for (var row = 0; row < 2; row++) ...[
                  if (row == 1) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var col = 0; col < 5; col++) ...[
                        if (col > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _MeterKey(
                            label: meters[row * 5 + col].label,
                            selected: engine.meterLabel == meters[row * 5 + col].label,
                            onTap: () => engine.setMeter(row * 5 + col),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
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
  const _BeatDot({
    required this.active,
    required this.strong,
    required this.onTap,
  });

  final bool active;
  final bool strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: active ? 18 : 14,
          height: active ? 18 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: strong ? color : Colors.transparent,
            border: Border.all(color: color, width: strong ? 0 : 1.5),
          ),
        ),
      ),
    );
  }
}

class _MeterKey extends StatelessWidget {
  const _MeterKey({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: selected
          ? const Color(0xFF1B7F4E)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
