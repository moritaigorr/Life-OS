import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/life/life_goal.dart';

void main() {
  group('LifeGoalDraft validation', () {
    test('accepts an annual goal with a success criterion', () {
      const draft = LifeGoalDraft(
        kind: LifeGoalKind.annual,
        year: 2026,
        title: 'Ler com frequência',
        successCriteria: 'Concluir 12 livros até dezembro',
        progress: 0,
      );

      expect(validateLifeGoalDraft(draft), isNull);
    });

    test('requires a quarter for quarterly goals', () {
      const draft = LifeGoalDraft(
        kind: LifeGoalKind.quarterly,
        year: 2026,
        title: 'Finalizar um curso',
        successCriteria: 'Certificado concluído',
        progress: 0,
      );

      expect(validateLifeGoalDraft(draft), 'Escolha o trimestre da meta.');
    });

    test('rejects progress outside zero to one hundred', () {
      const draft = LifeGoalDraft(
        kind: LifeGoalKind.annual,
        year: 2026,
        title: 'Ler com frequência',
        successCriteria: 'Concluir 12 livros',
        progress: 101,
      );

      expect(
        validateLifeGoalDraft(draft),
        'O progresso deve ficar entre 0 e 100%.',
      );
    });

    test('rejects a blank success criterion', () {
      const draft = LifeGoalDraft(
        kind: LifeGoalKind.annual,
        year: 2026,
        title: 'Ler com frequência',
        successCriteria: '   ',
        progress: 0,
      );

      expect(
        validateLifeGoalDraft(draft),
        'Descreva como saberá que a meta foi concluída.',
      );
    });
  });

  test('counts active quarterly goals and ignores archived goals', () {
    final goals = [
      for (var index = 0; index < 2; index++)
        LifeGoal(
          id: 'q$index',
          kind: LifeGoalKind.quarterly,
          year: 2026,
          quarter: 2,
          title: 'Meta $index',
          successCriteria: 'Critério $index',
          progress: 0,
        ),
      const LifeGoal(
        id: 'other-quarter',
        kind: LifeGoalKind.quarterly,
        year: 2026,
        quarter: 3,
        title: 'Outro trimestre',
        successCriteria: 'Critério',
        progress: 0,
      ),
      LifeGoal(
        id: 'archived',
        kind: LifeGoalKind.quarterly,
        year: 2026,
        quarter: 2,
        title: 'Arquivada',
        successCriteria: 'Critério',
        progress: 0,
        archivedAt: DateTime.utc(2026),
      ),
    ];

    expect(activeQuarterlyGoalCount(goals), 3);
    expect(shouldWarnForQuarterlyGoals(goals), isFalse);
  });

  test('warns when the user has more than three active quarterly goals', () {
    final goals = [
      for (var index = 0; index < 4; index++)
        LifeGoal(
          id: 'q$index',
          kind: LifeGoalKind.quarterly,
          year: 2026,
          quarter: 2,
          title: 'Meta $index',
          successCriteria: 'Critério $index',
          progress: 0,
        ),
    ];

    expect(activeQuarterlyGoalCount(goals), 4);
    expect(shouldWarnForQuarterlyGoals(goals), isTrue);
  });
}
