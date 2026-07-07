import 'package:flutter/material.dart';

import '../../domain/insights/body_energy_timeline.dart';
import '../../ui/theme/app_colors.dart';
import 'body_energy_display.dart';

/// The Body Energy day timeline: a smoothed 0-100 score line drawn by a
/// [CustomPainter], with a charge/drain influence-bar strip beneath. A trimmed
/// port of the Kotlin `BodyEnergyTimelineChart`.
class BodyEnergyTimelineChart extends StatelessWidget {
  const BodyEnergyTimelineChart({
    super.key,
    required this.points,
    required this.influenceBars,
  });

  final List<BodyEnergyChartPoint> points;
  final List<BodyEnergyInfluenceBar> influenceBars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 172,
          child: CustomPaint(
            painter: _LinePainter(
              points: points,
              lineColor: scheme.primary,
              gridColor: scheme.primary.withValues(alpha: 0.12),
              axisColor: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: CustomPaint(
            painter: _InfluenceBarsPainter(
              bars: influenceBars,
              axisColor: scheme.outlineVariant.withValues(alpha: 0.8),
              noDataColor: scheme.outline.withValues(alpha: 0.36),
              colorFor: (influence) => influenceColor(influence, scheme),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in const ['00:00', '06:00', '12:00', '18:00', '24:00'])
              Text(label, style: labelStyle),
          ],
        ),
      ],
    );
  }
}

/// The accent colour for a Body Energy influence (port of the Kotlin
/// `bodyEnergyInfluenceColor`).
Color influenceColor(BodyEnergyPrimaryInfluence influence, ColorScheme scheme) {
  switch (influence) {
    case BodyEnergyPrimaryInfluence.sleepRecovery:
      return AppColors.steps;
    case BodyEnergyPrimaryInfluence.quietRest:
      return AppColors.workout;
    case BodyEnergyPrimaryInfluence.exertion:
      return AppColors.calories;
    case BodyEnergyPrimaryInfluence.elevatedHeartRate:
      return AppColors.floors;
    case BodyEnergyPrimaryInfluence.recoveryDebt:
      return AppColors.heart;
    case BodyEnergyPrimaryInfluence.noData:
      return scheme.outline;
    case BodyEnergyPrimaryInfluence.steady:
      return scheme.onSurfaceVariant;
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.axisColor,
  });

  final List<BodyEnergyChartPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Horizontal guide lines at 0/25/50/75/100.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );
    if (points.isEmpty) return;

    final positioned = [
      for (final point in points)
        Offset(
          size.width * point.xFraction.clamp(0.0, 1.0),
          size.height * (1.0 - (point.score / 100.0).clamp(0.0, 1.0)),
        ),
    ];
    final path = Path()..moveTo(positioned.first.dx, positioned.first.dy);
    for (var i = 1; i < positioned.length; i++) {
      path.lineTo(positioned[i].dx, positioned[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (positioned.length <= 40) {
      final pointPaint = Paint()..color = lineColor;
      for (final offset in positioned) {
        canvas.drawCircle(offset, 3, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}

class _InfluenceBarsPainter extends CustomPainter {
  _InfluenceBarsPainter({
    required this.bars,
    required this.axisColor,
    required this.noDataColor,
    required this.colorFor,
  });

  final List<BodyEnergyInfluenceBar> bars;
  final Color axisColor;
  final Color noDataColor;
  final Color Function(BodyEnergyPrimaryInfluence) colorFor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );
    if (bars.isEmpty) return;

    var maxMagnitude = 0.0;
    for (final bar in bars) {
      final magnitude = bar.charge > bar.drain ? bar.charge : bar.drain;
      if (magnitude > maxMagnitude) maxMagnitude = magnitude;
    }
    if (maxMagnitude <= 0.0) maxMagnitude = 1.0;
    const minBarWidth = 2.0;

    for (final bar in bars) {
      final x = size.width * bar.xFraction.clamp(0.0, 1.0);
      final width = (size.width * bar.widthFraction * 0.82)
          .clamp(minBarWidth, size.width);
      final left =
          (x - width / 2).clamp(0.0, (size.width - width).clamp(0.0, size.width));
      final color = colorFor(bar.influence);
      if (bar.charge > 0.0) {
        final height =
            ((bar.charge / maxMagnitude) * centerY).clamp(1.0, centerY);
        canvas.drawRect(
          Rect.fromLTWH(left, centerY - height, width, height),
          Paint()..color = color,
        );
      }
      if (bar.drain > 0.0) {
        final height =
            ((bar.drain / maxMagnitude) * centerY).clamp(1.0, centerY);
        canvas.drawRect(
          Rect.fromLTWH(left, centerY, width, height),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InfluenceBarsPainter oldDelegate) => true;
}
