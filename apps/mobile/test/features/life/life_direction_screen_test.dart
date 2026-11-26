import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/life/life_area.dart';
import 'package:life_os/features/life/life_direction_repository.dart';
import 'package:life_os/features/life/life_direction_screen.dart';
import 'package:life_os/features/life/life_goal.dart';
import 'package:life_os/features/life/life_onboarding.dart';

class _FakeLifeDirectionRepository implements LifeDirectionRepository {
  LifeOnboardingState? state;
  List<LifeGoal> goals = const [];

  @override
  Future<void> ensureDefaultAreas() async {}

  @override
  Future<List<LifeArea>> listAreas() async => const [];

  @override
  Future<List<LifeGoal>> listGoals({bool includeArchived = false}) async =>
      includeArchived
      ? goals
      : goals.where((goal) => !goal.isArchived).toList();

  @override
  Future<void> createGoal(LifeGoalDraft draft) async {
    goals = [
      ...goals,
      LifeGoal(
        id: 'goal-${goals.length}',
        kind: draft.kind,
        year: draft.year,
        quarter: draft.quarter,
        title: draft.title.trim(),
        successCriteria: draft.successCriteria.trim(),
        progress: draft.progress,
        lifeAreaId: draft.lifeAreaId,
        parentGoalId: draft.parentGoalId,
      ),
    ];
  }

  @override
  Future<void> updateGoal(String goalId, LifeGoalDraft draft) async {
    goals = goals
        .map(
          (goal) => goal.id == goalId
              ? LifeGoal(
                  id: goal.id,
                  kind: draft.kind,
                  year: draft.year,
                  quarter: draft.quarter,
                  title: draft.title.trim(),
                  successCriteria: draft.successCriteria.trim(),
                  progress: draft.progress,
                  lifeAreaId: draft.lifeAreaId,
                  parentGoalId: draft.parentGoalId,
                  archivedAt: goal.archivedAt,
                )
              : goal,
        )
        .toList();
  }

  @override
  Future<void> setGoalArchived(String goalId, bool archived) async {
    goals = goals
        .map(
          (goal) => goal.id == goalId
              ? LifeGoal(
                  id: goal.id,
                  kind: goal.kind,
                  year: goal.year,
                  quarter: goal.quarter,
                  title: goal.title,
                  successCriteria: goal.successCriteria,
                  progress: goal.progress,
                  lifeAreaId: goal.lifeAreaId,
                  parentGoalId: goal.parentGoalId,
                  archivedAt: archived ? DateTime.utc(2026) : null,
                )
              : goal,
        )
        .toList();
  }

  @override
  Future<LifeOnboardingState?> getOnboardingState() async => state;

  @override
  Future<void> saveOnboardingState(LifeOnboardingState value) async {
    state = value;
  }
}

void main() {
  testWidgets('onboarding can be skipped and resumed at the saved step', (
    tester,
  ) async {
    final repository = _FakeLifeDirectionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LifeDirectionScreen(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Começar configuração'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lifeVisionInput')),
      'Ter tempo para cuidar da saúde',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Etapa 2 de 2'), findsOneWidget);
    expect(repository.state?.lifeVision, 'Ter tempo para cuidar da saúde');
    await tester.tap(find.text('Pular por agora'));
    await tester.pumpAndSettle();

    expect(find.text('Retomar configuração'), findsOneWidget);
    await tester.tap(find.text('Retomar configuração'));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 2 de 2'), findsOneWidget);
    expect(repository.state?.status, LifeOnboardingStatus.inProgress);
  });

  testWidgets('a goal can be created, edited and archived', (tester) async {
    final repository = _FakeLifeDirectionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LifeDirectionScreen(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adicionar meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meta anual'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goalTitleInput')),
      'Construir rotina',
    );
    await tester.enterText(
      find.byKey(const Key('goalCriteriaInput')),
      'Manter por doze semanas',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(repository.goals, hasLength(1));
    expect(find.text('Construir rotina'), findsOneWidget);

    await tester.ensureVisible(find.text('Construir rotina'));
    await tester.tap(find.text('Editar meta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goalCriteriaInput')),
      'Concluir doze semanas',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Concluir doze semanas'), findsOneWidget);

    await tester.ensureVisible(find.text('Construir rotina'));
    await tester.tap(find.text('Arquivar meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Arquivar'));
    await tester.pumpAndSettle();
    expect(find.text('Metas arquivadas (1)'), findsOneWidget);
    expect(repository.goals.single.isArchived, isTrue);
  });

  testWidgets('more than three quarterly goals shows a gentle focus warning', (
    tester,
  ) async {
    final repository = _FakeLifeDirectionRepository()
      ..goals = [
        for (var index = 0; index < 4; index++)
          LifeGoal(
            id: 'q$index',
            kind: LifeGoalKind.quarterly,
            year: 2026,
            quarter: index + 1,
            title: 'Meta ${index + 1}',
            successCriteria: 'Concluir um marco',
            progress: 0,
          ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: LifeDirectionScreen(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('mais de três metas trimestrais ativas'),
      findsOneWidget,
    );
  });

  testWidgets('vision draft is persisted before onboarding is completed', (
    tester,
  ) async {
    final repository = _FakeLifeDirectionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LifeDirectionScreen(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar configuração'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lifeVisionInput')),
      'Ter mais tempo com a família',
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(repository.state?.lifeVision, 'Ter mais tempo com a família');
    expect(repository.state?.currentStep, 0);
  });

  testWidgets('skipping immediately preserves the typed vision for later', (
    tester,
  ) async {
    final repository = _FakeLifeDirectionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LifeDirectionScreen(repository: repository, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar configuração'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lifeVisionInput')),
      'Aprender um novo idioma',
    );
    await tester.tap(find.text('Pular por agora'));
    await tester.pumpAndSettle();

    expect(repository.state?.status, LifeOnboardingStatus.skipped);
    expect(repository.state?.lifeVision, 'Aprender um novo idioma');
  });
}
