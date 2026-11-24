import 'task.dart';
import 'task_repository.dart';

class InvalidTaskTitle implements Exception {
  const InvalidTaskTitle();
}

class CreateTask {
  const CreateTask(this._repository);

  final TaskRepository _repository;

  Future<Task> call(String title, String operationId) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.runes.length > 200) {
      throw const InvalidTaskTitle();
    }
    return _repository.create(title: cleanTitle, operationId: operationId);
  }
}
