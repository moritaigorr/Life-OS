import 'package:supabase_flutter/supabase_flutter.dart';

import 'task.dart';
import 'task_repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Task>> listRecent() async {
    final rows = await _client
        .from('tasks')
        .select()
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .limit(100);
    return rows.map(Task.fromJson).toList(growable: false);
  }

  @override
  Future<Task> create({
    required String title,
    required String operationId,
  }) async {
    try {
      final row = await _client
          .from('tasks')
          .insert({'id': operationId, 'title': title})
          .select()
          .single();
      return Task.fromJson(row);
    } catch (_) {
      // A timeout can happen after Postgres committed. Reuse the operation ID
      // to read back that row instead of creating a duplicate on retry.
      try {
        final row = await _client
            .from('tasks')
            .select()
            .eq('id', operationId)
            .maybeSingle();
        if (row != null && row['user_id'] == _client.auth.currentUser?.id) {
          return Task.fromJson(row);
        }
      } catch (_) {
        // Preserve the original write error. The UI keeps the operation ID for
        // a later retry after the connection returns.
      }
      rethrow;
    }
  }
}
