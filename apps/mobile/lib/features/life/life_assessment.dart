class LifeScoreInput {
  const LifeScoreInput({
    required this.areaId,
    required this.score,
    required this.needsAttention,
  });

  final String areaId;
  final int score;
  final bool needsAttention;

  Map<String, Object> toJson() => {
    'area_id': areaId,
    'score': score,
    'needs_attention': needsAttention,
  };
}

class LifeAssessmentDraft {
  const LifeAssessmentDraft({
    required this.assessedOn,
    required this.comment,
    required this.scores,
  });

  final DateTime assessedOn;
  final String? comment;
  final List<LifeScoreInput> scores;
}

class LifeAssessmentScore {
  const LifeAssessmentScore({
    required this.areaId,
    required this.areaName,
    required this.sortOrder,
    required this.score,
    required this.needsAttention,
  });

  final String areaId;
  final String areaName;
  final int sortOrder;
  final int? score;
  final bool needsAttention;

  factory LifeAssessmentScore.fromJson(Map<String, dynamic> json) =>
      LifeAssessmentScore(
        areaId: json['life_area_id'] as String,
        areaName: json['area_name_snapshot'] as String,
        sortOrder: json['area_sort_order_snapshot'] as int,
        score: json['score'] as int?,
        needsAttention: json['needs_attention'] as bool,
      );
}

class LifeAssessment {
  const LifeAssessment({
    required this.id,
    required this.assessedOn,
    required this.scores,
    this.comment,
    this.archivedAt,
  });

  final String id;
  final DateTime assessedOn;
  final String? comment;
  final DateTime? archivedAt;
  final List<LifeAssessmentScore> scores;

  bool get isArchived => archivedAt != null;

  double get average {
    final rated = scores.where((item) => item.score != null);
    if (rated.isEmpty) return 0;
    return rated.fold<int>(0, (sum, item) => sum + item.score!) / rated.length;
  }
}
