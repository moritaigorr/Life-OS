import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/life/life_assessment.dart';

void main() {
  test('an archived assessment remains available as historical data', () {
    final assessment = LifeAssessment(
      id: 'assessment-a',
      assessedOn: DateTime(2026, 11, 25),
      archivedAt: DateTime.utc(2026, 11, 26),
      comment: 'Revisão pessoal',
      scores: const [
        LifeAssessmentScore(
          areaId: 'area-a',
          areaName: 'Saúde física',
          sortOrder: 0,
          score: 8,
          needsAttention: false,
        ),
        LifeAssessmentScore(
          areaId: 'area-b',
          areaName: 'Lazer',
          sortOrder: 1,
          score: null,
          needsAttention: false,
        ),
      ],
    );

    expect(assessment.isArchived, isTrue);
    expect(assessment.average, 8);
    expect(assessment.scores.map((score) => score.areaName), [
      'Saúde física',
      'Lazer',
    ]);
  });
}
