import 'package:flutter/material.dart';

import '../../core/music/guitar_tuning.dart';
import 'pitch_engine.dart';
import 'tuner_gauge.dart';

class TunerPage extends StatelessWidget {
  const TunerPage({super.key, required this.engine});

  final PitchEngine engine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final reading = engine.reading;
        final selected = engine.lockedStringNumber == null
            ? null
            : GuitarTuning.byNumber(engine.lockedStringNumber!);

        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '吉他调音器',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected == null
                      ? '自动'
                      : '${selected.frequency.toStringAsFixed(1)} Hz',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (engine.permissionDenied) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => engine.start(),
                    child: const Text('需要麦克风权限，点此授权'),
                  ),
                ],
                const Spacer(),
                Text(
                  reading?.string.noteName ?? '—',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -1,
                    color: reading?.inTune == true
                        ? const Color(0xFF1B7F4E)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reading != null
                      ? '${reading.frequency.toStringAsFixed(1)} Hz'
                      : '-- Hz',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Text(
                    reading == null
                        ? ''
                        : '${reading.cents >= 0 ? '+' : ''}${reading.cents.toStringAsFixed(0)} 音分',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 210,
                  child: TunerDisplay(
                    cents: reading?.cents ?? 0,
                    inTune: reading?.inTune ?? false,
                    hasSignal: reading != null,
                    targetHz: selected?.frequency ?? reading?.string.frequency,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    for (final s in GuitarTuning.standard) ...[
                      _StringKey(
                        label: '${s.number}',
                        caption: s.noteName,
                        selected: selected?.number == s.number,
                        onTap: () => engine.setLockedString(
                          selected?.number == s.number ? null : s.number,
                        ),
                      ),
                      if (s.number != 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StringKey extends StatelessWidget {
  const _StringKey({
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? const Color(0xFF1B7F4E) : scheme.surfaceContainerHighest;
    final fg = selected ? Colors.white : scheme.onSurface;

    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: caption == null ? 13 : 16,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
