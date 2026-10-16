import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum TunerStyle { needle, trace }

/// Tap to switch between a needle and a pitch-over-time trace.
class TunerDisplay extends StatefulWidget {
  const TunerDisplay({
    super.key,
    required this.cents,
    required this.inTune,
    required this.hasSignal,
    this.targetHz,
  });

  final double cents;
  final bool inTune;
  final bool hasSignal;
  final double? targetHz;

  @override
  State<TunerDisplay> createState() => _TunerDisplayState();
}

class _TunerDisplayState extends State<TunerDisplay> {
  TunerStyle _style = TunerStyle.needle;
  final List<double?> _history = [];
  Timer? _timer;
  double? _latestCents;
  double? _trackedTarget;

  static const int _slots = 56;

  @override
  void initState() {
    super.initState();
    _latestCents = widget.hasSignal ? widget.cents : null;
    _trackedTarget = widget.targetHz;
    _timer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted) return;
      setState(() {
        _history.add(_latestCents);
        if (_history.length > _slots) {
          _history.removeAt(0);
        }
      });
    });
  }

  @override
  void didUpdateWidget(TunerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetHz != null &&
        _trackedTarget != null &&
        (widget.targetHz! - _trackedTarget!).abs() > 0.4) {
      _history.clear();
    }
    _trackedTarget = widget.targetHz;
    _latestCents = widget.hasSignal ? widget.cents : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _style = _style == TunerStyle.needle ? TunerStyle.trace : TunerStyle.needle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inTuneColor = const Color(0xFF1B7F4E);
    final offColor = theme.colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _style == TunerStyle.needle
                  ? _NeedlePainter(
                      cents: widget.hasSignal ? widget.cents.clamp(-50.0, 50.0) : 0,
                      hasSignal: widget.hasSignal,
                      inTune: widget.inTune,
                      track: theme.colorScheme.outlineVariant,
                      needle: widget.inTune ? inTuneColor : offColor,
                      zone: inTuneColor,
                    )
                  : _TracePainter(
                      history: List<double?>.from(_history),
                      inTune: widget.inTune,
                      line: inTuneColor,
                      dot: widget.inTune ? inTuneColor : offColor,
                      grid: theme.colorScheme.outlineVariant,
                    ),
              child: const SizedBox.expand(),
            ),
          ),
          Icon(
            _style == TunerStyle.needle ? Icons.show_chart : Icons.speed,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({
    required this.cents,
    required this.hasSignal,
    required this.inTune,
    required this.track,
    required this.needle,
    required this.zone,
  });

  final double cents;
  final bool hasSignal;
  final bool inTune;
  final Color track;
  final Color needle;
  final Color zone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.86);
    final radius = math.min(size.width * 0.42, size.height * 0.78);
    const start = math.pi;
    const sweep = math.pi;

    final arc = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );

    final zonePaint = Paint()
      ..color = zone.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final zoneAngle = start + sweep * 0.5;
    final zoneHalf = sweep * (4 / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      zoneAngle - zoneHalf,
      zoneHalf * 2,
      false,
      zonePaint,
    );

    final tick = Paint()
      ..color = track
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final mark in [-50.0, -25.0, 0.0, 25.0, 50.0]) {
      final a = start + sweep * ((mark + 50) / 100);
      final outer = radius + (mark == 0 ? 8 : 5);
      final inner = radius - (mark == 0 ? 0 : 4);
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * inner, center.dy + math.sin(a) * inner),
        Offset(center.dx + math.cos(a) * outer, center.dy + math.sin(a) * outer),
        tick..color = mark == 0 ? zone : track,
      );
    }

    if (!hasSignal) {
      canvas.drawCircle(center, 3, Paint()..color = track);
      return;
    }

    final angle = start + sweep * ((cents + 50) / 100);
    final tip = Offset(
      center.dx + math.cos(angle) * (radius - 10),
      center.dy + math.sin(angle) * (radius - 10),
    );
    final back = Offset(
      center.dx - math.cos(angle) * 10,
      center.dy - math.sin(angle) * 10,
    );
    canvas.drawLine(
      back,
      tip,
      Paint()
        ..color = needle
        ..strokeWidth = inTune ? 2 : 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 4, Paint()..color = needle);
    canvas.drawCircle(center, 1.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.hasSignal != hasSignal ||
        oldDelegate.inTune != inTune;
  }
}

/// ±1 semitone. Center is the target pitch.
const double _traceHalfRange = 100;

double _traceX(Rect rect, double cents) {
  final t = (cents.clamp(-_traceHalfRange, _traceHalfRange) + _traceHalfRange) /
      (2 * _traceHalfRange);
  return rect.left + rect.width * t;
}

/// Center vertical line is the target pitch. X is frequency offset, Y is time.
class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.history,
    required this.inTune,
    required this.line,
    required this.dot,
    required this.grid,
  });

  final List<double?> history;
  final bool inTune;
  final Color line;
  final Color dot;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 4, size.width, size.height - 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = grid.withValues(alpha: 0.18),
    );

    final midX = rect.center.dx;
    canvas.drawLine(
      Offset(midX, rect.top + 6),
      Offset(midX, rect.bottom - 6),
      Paint()
        ..color = line
        ..strokeWidth = 1.5,
    );

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (final mark in [-50.0, 50.0]) {
      final x = _traceX(rect, mark);
      canvas.drawLine(Offset(x, rect.top + 8), Offset(x, rect.bottom - 8), gridPaint);
    }

    if (history.isEmpty) return;
    const step = 6.0;
    final n = history.length;
    final bottom = rect.bottom - 10;
    final dotPaint = Paint()..color = dot;
    for (var i = 0; i < n; i++) {
      final cents = history[i];
      if (cents == null) continue;
      final age = n - 1 - i;
      final y = bottom - age * step;
      if (y < rect.top + 6) continue;
      final x = _traceX(rect, cents);
      final newest = age == 0;
      canvas.drawCircle(Offset(x, y), newest ? 3.2 : 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) {
    return true;
  }
}
