import 'life_area.dart';
import 'life_assessment.dart';

abstract interface class LifeRepository {
  Future<void> ensureDefaultAreas();

  Future<List<LifeArea>> listAreas();

  Future<void> renameArea(String areaId, String name);

  Future<void> setAreaArchived(String areaId, bool archived);

  Future<void> reorderAreas(List<String> areaIds);

  Future<List<LifeAssessment>> listAssessments({
    required int offset,
    required int limit,
  });

  Future<void> createAssessment({
    required String operationId,
    required LifeAssessmentDraft draft,
  });

  Future<void> updateAssessment({
    required String assessmentId,
    required LifeAssessmentDraft draft,
  });

  Future<void> setAssessmentArchived(String assessmentId, bool archived);
}
