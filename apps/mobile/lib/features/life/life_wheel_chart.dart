import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'life_assessment.dart';

class LifeWheelChart extends StatelessWidget {
  const LifeWheelChart({required this.scores, super.key});

  final List<LifeAssessmentScore> scores;

  @override
  Widget build(BuildContext context) {
    final description = scores
        .where((score) => score.score != null)
        .map((score) => '${score.areaName}: ${score.score} de 10')
        .join(', ');
    return Semantics(
      container: true,
      label: 'Roda da vida. $description',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 280,
          child: CustomPaint(painter: _LifeWheelPainter(scores)),
        ),
      ),
    );
  }
}

class _LifeWheelPainter extends CustomPainter {
  const _LifeWheelPainter(this.scores);

  final List<LifeAssessmentScore> scores;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    final currentPaint = Paint()
      ..color = AppColors.violet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final fillPaint = Paint()
      ..color = AppColors.violet.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;
    final pointPaint = Paint()
      ..color = AppColors.violet
      ..style = PaintingStyle.fill;

    for (var ring = 1; ring <= 5; ring++) {
      canvas.drawCircle(center, radius * ring / 5, gridPaint);
    }

    for (var index = 0; index < scores.length; index++) {
      final angle = _angle(index, scores.length);
      canvas.drawLine(center, _point(center, radius, angle), axisPaint);
    }

    final hasEveryScore =
        scores.length >= 3 && scores.every((score) => score.score != null);
    if (hasEveryScore) {
      final polygon = Path();
      for (var index = 0; index < scores.length; index++) {
        final point = _scorePoint(center, radius, index, scores[index].score!);
        if (index == 0) {
          polygon.moveTo(point.dx, point.dy);
        } else {
          polygon.lineTo(point.dx, point.dy);
        }
      }
      polygon.close();
      canvas.drawPath(polygon, fillPaint);
      canvas.drawPath(polygon, currentPaint);
    } else {
      for (var index = 0; index < scores.length; index++) {
        final nextIndex = (index + 1) % scores.length;
        final currentScore = scores[index].score;
        final nextScore = scores[nextIndex].score;
        if (currentScore == null || nextScore == null) continue;
        canvas.drawLine(
          _scorePoint(center, radius, index, currentScore),
          _scorePoint(center, radius, nextIndex, nextScore),
          currentPaint,
        );
      }
    }

    for (var index = 0; index < scores.length; index++) {
      final score = scores[index].score;
      if (score == null) continue;
      final point = _scorePoint(center, radius, index, score);
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  Offset _point(Offset center, double radius, double angle) => Offset(
    center.dx + math.cos(angle) * radius,
    center.dy + math.sin(angle) * radius,
  );

  Offset _scorePoint(Offset center, double radius, int index, int score) =>
      _point(center, radius * score / 10, _angle(index, scores.length));

  double _angle(int index, int count) =>
      -math.pi / 2 + 2 * math.pi * index / count;

  @override
  bool shouldRepaint(covariant _LifeWheelPainter oldDelegate) =>
      oldDelegate.scores != scores;
}
