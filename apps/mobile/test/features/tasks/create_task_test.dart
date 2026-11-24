import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/create_task.dart';
import 'package:life_os/features/tasks/task.dart';
import 'package:life_os/features/tasks/task_repository.dart';

class _FakeTaskRepository implements TaskRepository {
  String? createdTitle;
  String? createdId;

  @override
  Future<Task> create({
    required String title,
    required String operationId,
  }) async {
    createdTitle = title;
    createdId = operationId;
    return Task(
      id: operationId,
      userId: 'user-a',
      title: title,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<List<Task>> listRecent() async => const [];
}

void main() {
  test('trims task titles and preserves the operation ID', () async {
    final repository = _FakeTaskRepository();
    final createTask = CreateTask(repository);

    final task = await createTask('  Read for 20 minutes  ', 'operation-1');

    expect(task.title, 'Read for 20 minutes');
    expect(repository.createdTitle, 'Read for 20 minutes');
    expect(repository.createdId, 'operation-1');
  });

  test('rejects a blank title before contacting the repository', () async {
    final repository = _FakeTaskRepository();
    final createTask = CreateTask(repository);

    await expectLater(
      createTask('   ', 'operation-2'),
      throwsA(isA<InvalidTaskTitle>()),
    );
    expect(repository.createdId, isNull);
  });

  test('accepts 200 characters and rejects 201', () async {
    final repository = _FakeTaskRepository();
    final createTask = CreateTask(repository);

    await createTask('x' * 200, 'operation-3');
    expect(repository.createdTitle, hasLength(200));
    await createTask('💪' * 101, 'operation-emoji');
    expect(repository.createdTitle, '💪' * 101);
    await expectLater(
      createTask('💪' * 201, 'operation-4'),
      throwsA(isA<InvalidTaskTitle>()),
    );
    expect(repository.createdId, 'operation-emoji');
  });
}
