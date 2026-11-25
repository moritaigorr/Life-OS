class LifeArea {
  const LifeArea({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.templateKey,
    this.archivedAt,
  });

  final String id;
  final String name;
  final int sortOrder;
  final String? templateKey;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory LifeArea.fromJson(Map<String, dynamic> json) => LifeArea(
    id: json['id'] as String,
    name: json['name'] as String,
    sortOrder: json['sort_order'] as int,
    templateKey: json['template_key'] as String?,
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
  );
}

String? validateLifeAreaName(String value) {
  final name = value.trim();
  if (name.isEmpty) return 'Digite um nome para a área.';
  if (name.runes.length > 60) return 'Use até 60 caracteres.';
  return null;
}
