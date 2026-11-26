import 'package:supabase_flutter/supabase_flutter.dart';

import 'life_area.dart';
import 'life_direction_repository.dart';
import 'life_goal.dart';
import 'life_onboarding.dart';

class SupabaseLifeDirectionRepository implements LifeDirectionRepository {
  const SupabaseLifeDirectionRepository(this._client);

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
        .isFilter('archived_at', null)
        .order('sort_order');
    return rows.map((row) => LifeArea.fromJson(row)).toList(growable: false);
  }

  @override
  Future<List<LifeGoal>> listGoals({bool includeArchived = false}) async {
    var query = _client
        .from('life_goals')
        .select(
          'id, kind, year, quarter, parent_goal_id, life_area_id, title, '
          'success_criteria, progress, archived_at',
        );
    if (!includeArchived) query = query.isFilter('archived_at', null);
    final rows = await query
        .order('year', ascending: false)
        .order('kind')
        .order('quarter');
    if (rows.isEmpty) return const [];

    final areaIds = rows
        .map((row) => row['life_area_id'] as String?)
        .whereType<String>()
        .toSet();
    final areaNames = <String, String>{};
    if (areaIds.isNotEmpty) {
      final areaRows = await _client
          .from('life_areas')
          .select('id, name')
          .inFilter('id', areaIds.toList(growable: false));
      for (final area in areaRows) {
        areaNames[area['id'] as String] = area['name'] as String;
      }
    }

    return rows
        .map(
          (row) => LifeGoal.fromJson({
            ...row,
            'life_area_name': areaNames[row['life_area_id']],
          }),
        )
        .toList(growable: false);
  }

  @override
  Future<void> createGoal(LifeGoalDraft draft) async {
    final error = validateLifeGoalDraft(draft);
    if (error != null) throw InvalidLifeGoal(error);
    await _client.from('life_goals').insert(draft.toJson());
  }

  @override
  Future<void> updateGoal(String goalId, LifeGoalDraft draft) async {
    final error = validateLifeGoalDraft(draft);
    if (error != null) throw InvalidLifeGoal(error);
    await _client.from('life_goals').update(draft.toJson()).eq('id', goalId);
  }

  @override
  Future<void> setGoalArchived(String goalId, bool archived) async {
    await _client
        .from('life_goals')
        .update({
          'archived_at': archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', goalId);
  }

  @override
  Future<LifeOnboardingState?> getOnboardingState() async {
    final row = await _client
        .from('life_onboarding')
        .select('status, current_step, life_vision')
        .maybeSingle();
    return row == null ? null : LifeOnboardingState.fromJson(row);
  }

  @override
  Future<void> saveOnboardingState(LifeOnboardingState state) async {
    await _client
        .from('life_onboarding')
        .upsert(state.toJson(), onConflict: 'user_id');
  }
}
