import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Needle gauge showing cents deviation (−50 … +50).
class TunerGauge extends StatelessWidget {
  const TunerGauge({
    super.key,
    required this.cents,
    required this.inTune,
    this.hasSignal = false,
  });

  final double cents;
  final bool inTune;
  final bool hasSignal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 2,
      child: CustomPaint(
        painter: _GaugePainter(
          cents: cents.clamp(-50.0, 50.0),
          inTune: inTune,
          hasSignal: hasSignal,
          trackColor: theme.colorScheme.surfaceContainerHighest,
          needleColor: inTune
              ? theme.colorScheme.primary
              : theme.colorScheme.tertiary,
          centerColor: theme.colorScheme.primary,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              hasSignal
                  ? (inTune
                      ? '准了'
                      : (cents < 0 ? '偏低' : '偏高'))
                  : '拨弦测音',
              style: theme.textTheme.titleMedium?.copyWith(
                color: hasSignal && inTune
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.cents,
    required this.inTune,
    required this.hasSignal,
    required this.trackColor,
    required this.needleColor,
    required this.centerColor,
  });

  final double cents;
  final bool inTune;
  final bool hasSignal;
  final Color trackColor;
  final Color needleColor;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width * 0.42;
    const start = math.pi;
    const sweep = math.pi;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    // In-tune zone (±5 cents).
    final zonePaint = Paint()
      ..color = centerColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;
    final zoneStart = start + sweep * ((50 - 5) / 100);
    final zoneSweep = sweep * (10 / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      zoneStart,
      zoneSweep,
      false,
      zonePaint,
    );

    // Tick marks.
    final tickPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2;
    for (final t in [-50.0, -25.0, 0.0, 25.0, 50.0]) {
      final a = start + sweep * ((t + 50) / 100);
      final outer = Offset(
        center.dx + math.cos(a) * (radius + 10),
        center.dy + math.sin(a) * (radius + 10),
      );
      final inner = Offset(
        center.dx + math.cos(a) * (radius - 10),
        center.dy + math.sin(a) * (radius - 10),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    if (!hasSignal) return;

    final angle = start + sweep * ((cents + 50) / 100);
    final tip = Offset(
      center.dx + math.cos(angle) * (radius - 8),
      center.dy + math.sin(angle) * (radius - 8),
    );
    final needle = Paint()
      ..color = needleColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(center, 8, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.inTune != inTune ||
        oldDelegate.hasSignal != hasSignal;
  }
}
