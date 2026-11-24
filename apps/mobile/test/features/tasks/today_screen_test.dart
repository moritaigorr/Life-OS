import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/task.dart';
import 'package:life_os/features/tasks/task_repository.dart';
import 'package:life_os/features/tasks/today_screen.dart';
import 'package:material_ui/material_ui.dart';

class _FakeTaskRepository implements TaskRepository {
  final List<Task> rows = [];
  final List<String> operationIds = [];
  bool failAfterFirstCommit = true;

  @override
  Future<List<Task>> listRecent() async => List.of(rows.reversed);

  @override
  Future<Task> create({
    required String title,
    required String operationId,
  }) async {
    operationIds.add(operationId);
    final existing = rows.where((task) => task.id == operationId);
    if (existing.isNotEmpty) return existing.first;

    final task = Task(
      id: operationId,
      userId: 'user-a',
      title: title,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    rows.add(task);
    if (failAfterFirstCommit) {
      failAfterFirstCommit = false;
      throw TimeoutException('response lost after commit');
    }
    return task;
  }
}

void main() {
  testWidgets('retry after an ambiguous timeout reuses the operation ID', (
    tester,
  ) async {
    final repository = _FakeTaskRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(repository: repository, onSignOut: _ignoreSignOut),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Revisar agenda');
    await tester.tap(find.byTooltip('Salvar tarefa'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível salvar. Confira a conexão e tente novamente.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(find.byTooltip('Salvar tarefa'));
    await tester.pumpAndSettle();

    expect(repository.operationIds, hasLength(2));
    expect(repository.operationIds.first, repository.operationIds.last);
    expect(repository.rows, hasLength(1));
    expect(find.text('Revisar agenda'), findsOneWidget);
  });
}

void _ignoreSignOut() {}
