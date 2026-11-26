import 'life_area.dart';
import 'life_goal.dart';
import 'life_onboarding.dart';

abstract interface class LifeDirectionRepository {
  Future<void> ensureDefaultAreas();

  Future<List<LifeArea>> listAreas();

  Future<List<LifeGoal>> listGoals({bool includeArchived = false});

  Future<void> createGoal(LifeGoalDraft draft);

  Future<void> updateGoal(String goalId, LifeGoalDraft draft);

  Future<void> setGoalArchived(String goalId, bool archived);

  Future<LifeOnboardingState?> getOnboardingState();

  Future<void> saveOnboardingState(LifeOnboardingState state);
}

class InvalidLifeGoal implements Exception {
  const InvalidLifeGoal(this.message);

  final String message;
}
