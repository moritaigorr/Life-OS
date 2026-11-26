import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/life/life_area.dart';
import 'package:life_os/features/life/life_assessment.dart';
import 'package:life_os/features/life/life_repository.dart';
import 'package:life_os/features/life/life_screen.dart';

class _FakeLifeRepository implements LifeRepository {
  final area = const LifeArea(id: 'area-a', name: 'Saúde física', sortOrder: 0);
  final List<LifeAssessment> assessments = [
    LifeAssessment(
      id: 'assessment-a',
      assessedOn: DateTime(2026, 11, 20),
      comment: 'Plano inicial',
      scores: const [
        LifeAssessmentScore(
          areaId: 'area-a',
          areaName: 'Saúde física',
          sortOrder: 0,
          score: 6,
          needsAttention: false,
        ),
      ],
    ),
  ];

  @override
  Future<void> ensureDefaultAreas() async {}

  @override
  Future<List<LifeArea>> listAreas() async => [area];

  @override
  Future<void> renameArea(String areaId, String name) async {}

  @override
  Future<void> setAreaArchived(String areaId, bool archived) async {}

  @override
  Future<void> reorderAreas(List<String> areaIds) async {}

  @override
  Future<List<LifeAssessment>> listAssessments({
    required int offset,
    required int limit,
  }) async => assessments.skip(offset).take(limit).toList();

  @override
  Future<void> createAssessment({
    required String operationId,
    required LifeAssessmentDraft draft,
  }) async {}

  @override
  Future<void> updateAssessment({
    required String assessmentId,
    required LifeAssessmentDraft draft,
  }) async {
    final index = assessments.indexWhere((item) => item.id == assessmentId);
    assessments[index] = LifeAssessment(
      id: assessmentId,
      assessedOn: draft.assessedOn,
      comment: draft.comment,
      scores: [
        for (final score in draft.scores)
          LifeAssessmentScore(
            areaId: score.areaId,
            areaName: area.name,
            sortOrder: area.sortOrder,
            score: score.score,
            needsAttention: score.needsAttention,
          ),
      ],
    );
  }

  @override
  Future<void> setAssessmentArchived(String assessmentId, bool archived) async {
    final index = assessments.indexWhere((item) => item.id == assessmentId);
    final old = assessments[index];
    assessments[index] = LifeAssessment(
      id: old.id,
      assessedOn: old.assessedOn,
      archivedAt: archived ? DateTime.utc(2026, 11, 25) : null,
      comment: old.comment,
      scores: old.scores,
    );
  }
}

void main() {
  testWidgets('an assessment can be edited, archived and restored', (
    tester,
  ) async {
    final repository = _FakeLifeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LifeScreen(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar avaliação'));
    await tester.pumpAndSettle();
    expect(find.text('Data da avaliação'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Plano atualizado');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Plano atualizado'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Arquivar'));
    await tester.pumpAndSettle();
    expect(find.text('Avaliações arquivadas (1)'), findsOneWidget);
    await tester.tap(find.text('Avaliações arquivadas (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restaurar'));
    await tester.pumpAndSettle();
    expect(repository.assessments.single.isArchived, isFalse);
    expect(find.text('Plano atualizado'), findsOneWidget);
  });
}
