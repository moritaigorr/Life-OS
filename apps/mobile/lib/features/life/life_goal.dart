enum LifeGoalKind { annual, quarterly }

class LifeGoalDraft {
  const LifeGoalDraft({
    required this.kind,
    required this.year,
    this.quarter,
    required this.title,
    required this.successCriteria,
    required this.progress,
    this.lifeAreaId,
    this.parentGoalId,
  });

  final LifeGoalKind kind;
  final int year;
  final int? quarter;
  final String title;
  final String successCriteria;
  final int progress;
  final String? lifeAreaId;
  final String? parentGoalId;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'year': year,
    'quarter': kind == LifeGoalKind.quarterly ? quarter : null,
    'title': title.trim(),
    'success_criteria': successCriteria.trim(),
    'progress': progress,
    'life_area_id': lifeAreaId,
    'parent_goal_id': parentGoalId,
  };
}

class LifeGoal {
  const LifeGoal({
    required this.id,
    required this.kind,
    required this.year,
    this.quarter,
    required this.title,
    required this.successCriteria,
    required this.progress,
    this.lifeAreaId,
    this.parentGoalId,
    this.lifeAreaName,
    this.archivedAt,
  });

  final String id;
  final LifeGoalKind kind;
  final int year;
  final int? quarter;
  final String title;
  final String successCriteria;
  final int progress;
  final String? lifeAreaId;
  final String? parentGoalId;
  final String? lifeAreaName;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory LifeGoal.fromJson(Map<String, dynamic> json) => LifeGoal(
    id: json['id'] as String,
    kind: LifeGoalKind.values.byName(json['kind'] as String),
    year: json['year'] as int,
    quarter: json['quarter'] as int?,
    title: json['title'] as String,
    successCriteria: json['success_criteria'] as String,
    progress: json['progress'] as int,
    lifeAreaId: json['life_area_id'] as String?,
    parentGoalId: json['parent_goal_id'] as String?,
    lifeAreaName: json['life_area_name'] as String?,
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
  );
}

String? validateLifeGoalDraft(LifeGoalDraft draft) {
  final title = draft.title.trim();
  final criteria = draft.successCriteria.trim();
  if (title.isEmpty || title.length > 120) {
    return 'Informe um título de até 120 caracteres.';
  }
  if (draft.kind == LifeGoalKind.quarterly &&
      (draft.quarter == null || draft.quarter! < 1 || draft.quarter! > 4)) {
    return 'Escolha o trimestre da meta.';
  }
  if (draft.kind == LifeGoalKind.annual && draft.quarter != null) {
    return 'Uma meta anual não pode ter trimestre.';
  }
  if (criteria.isEmpty || criteria.length > 500) {
    return 'Descreva como saberá que a meta foi concluída.';
  }
  if (draft.progress < 0 || draft.progress > 100) {
    return 'O progresso deve ficar entre 0 e 100%.';
  }
  if (draft.year < 2000 || draft.year > 2200) {
    return 'Informe um ano válido.';
  }
  if (draft.kind == LifeGoalKind.annual && draft.parentGoalId != null) {
    return 'Uma meta anual não pode depender de outra meta.';
  }
  return null;
}

int activeQuarterlyGoalCount(List<LifeGoal> goals) => goals
    .where((goal) => !goal.isArchived && goal.kind == LifeGoalKind.quarterly)
    .length;

bool shouldWarnForQuarterlyGoals(List<LifeGoal> goals) =>
    activeQuarterlyGoalCount(goals) > 3;
