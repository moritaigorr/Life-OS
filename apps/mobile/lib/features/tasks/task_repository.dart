import 'task.dart';

abstract interface class TaskRepository {
  Future<List<Task>> listRecent();

  Future<Task> create({required String title, required String operationId});
}
