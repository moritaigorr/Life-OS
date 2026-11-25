import 'package:supabase_flutter/supabase_flutter.dart';

import 'life_area.dart';
import 'life_assessment.dart';
import 'life_repository.dart';

class SupabaseLifeRepository implements LifeRepository {
  const SupabaseLifeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> ensureDefaultAreas() async {
    await _client.rpc('ensure_default_life_areas');
  }

  @override
  Future<List<LifeArea>> listAreas() async {
    final rows = await _client
        .from('life_areas')
        .select('id, name, sort_order, template_key, archived_at')
        .order('sort_order')
        .order('created_at');
    return rows.map((row) => LifeArea.fromJson(row)).toList(growable: false);
  }

  @override
  Future<void> renameArea(String areaId, String name) async {
    final message = validateLifeAreaName(name);
    if (message != null) throw InvalidLifeAreaName(message);
    await _client
        .from('life_areas')
        .update({'name': name.trim()})
        .eq('id', areaId);
  }

  @override
  Future<void> setAreaArchived(String areaId, bool archived) async {
    await _client.rpc(
      'set_life_area_archived',
      params: {'p_area_id': areaId, 'p_archived': archived},
    );
  }

  @override
  Future<void> reorderAreas(List<String> areaIds) async {
    await _client.rpc('reorder_life_areas', params: {'p_area_ids': areaIds});
  }

  @override
  Future<List<LifeAssessment>> listAssessments({
    required int offset,
    required int limit,
  }) async {
    final rows = await _client
        .from('assessments')
        .select('id, assessed_on, comment')
        .order('assessed_on', ascending: false)
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    if (rows.isEmpty) return const [];

    final ids = rows.map((row) => row['id'] as String).toList();
    final scoreRows = await _client
        .from('assessment_scores')
        .select(
          'assessment_id, life_area_id, area_name_snapshot, '
          'area_sort_order_snapshot, score, needs_attention',
        )
        .inFilter('assessment_id', ids)
        .order('area_sort_order_snapshot');
    final scoresByAssessment = <String, List<LifeAssessmentScore>>{};
    for (final row in scoreRows) {
      final assessmentId = row['assessment_id'] as String;
      scoresByAssessment
          .putIfAbsent(assessmentId, () => [])
          .add(LifeAssessmentScore.fromJson(row));
    }

    return rows
        .map((row) {
          final id = row['id'] as String;
          return LifeAssessment(
            id: id,
            assessedOn: DateTime.parse(row['assessed_on'] as String),
            comment: row['comment'] as String?,
            scores: List.unmodifiable(
              scoresByAssessment[id] ?? const <LifeAssessmentScore>[],
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> createAssessment({
    required String operationId,
    required LifeAssessmentDraft draft,
  }) async {
    final comment = draft.comment?.trim();
    if (draft.scores.isEmpty) throw const InvalidLifeAssessment();
    if (comment != null && comment.runes.length > 1000) {
      throw const InvalidLifeAssessment();
    }
    final date =
        '${draft.assessedOn.year.toString().padLeft(4, '0')}'
        '-${draft.assessedOn.month.toString().padLeft(2, '0')}'
        '-${draft.assessedOn.day.toString().padLeft(2, '0')}';
    await _client.rpc(
      'create_life_assessment',
      params: {
        'p_assessment_id': operationId,
        'p_assessed_on': date,
        'p_comment': comment == null || comment.isEmpty ? null : comment,
        'p_scores': draft.scores.map((score) => score.toJson()).toList(),
      },
    );
  }
}

class InvalidLifeAreaName implements Exception {
  const InvalidLifeAreaName(this.message);

  final String message;
}

class InvalidLifeAssessment implements Exception {
  const InvalidLifeAssessment();
}
