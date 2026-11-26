import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../theme/app_theme.dart';
import 'life_area.dart';
import 'life_assessment.dart';
import 'life_assessment_editor.dart';
import 'life_repository.dart';
import 'life_wheel_chart.dart';

class LifeScreen extends StatefulWidget {
  const LifeScreen({
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final LifeRepository repository;
  final VoidCallback onSignOut;

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  static const _pageSize = 12;
  static const _uuid = Uuid();

  late Future<_LifeSnapshot> _snapshot;
  String? _selectedAssessmentId;
  LifeAssessmentDraft? _pendingDraft;
  String? _pendingOperationId;
  bool _pendingIsUpdate = false;
  String? _actionMessage;
  bool _actionIsError = false;
  bool _saving = false;
  bool _loadingMore = false;
  bool _hasMoreAssessments = true;

  @override
  void initState() {
    super.initState();
    _snapshot = _loadSnapshot();
  }

  Future<_LifeSnapshot> _loadSnapshot() async {
    await widget.repository.ensureDefaultAreas();
    final results = await Future.wait([
      widget.repository.listAreas(),
      widget.repository.listAssessments(offset: 0, limit: _pageSize),
    ]);
    final areas = results[0] as List<LifeArea>;
    final assessments = results[1] as List<LifeAssessment>;
    _hasMoreAssessments = assessments.length == _pageSize;
    return _LifeSnapshot(areas: areas, assessments: assessments);
  }

  Future<void> _refresh() async {
    setState(() {
      _selectedAssessmentId = null;
      _hasMoreAssessments = true;
      _snapshot = _loadSnapshot();
    });
    await _snapshot;
  }

  Future<void> _loadMoreAssessments(_LifeSnapshot current) async {
    if (_loadingMore || !_hasMoreAssessments) return;
    setState(() => _loadingMore = true);
    try {
      final more = await widget.repository.listAssessments(
        offset: current.assessments.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _hasMoreAssessments = more.length == _pageSize;
        _snapshot = Future.value(
          _LifeSnapshot(
            areas: current.areas,
            assessments: [...current.assessments, ...more],
          ),
        );
      });
    } catch (_) {
      if (mounted) {
        _showMessage('Não foi possível carregar o histórico.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _startAssessment(
    List<LifeArea> activeAreas, {
    LifeAssessment? initialAssessment,
  }) async {
    if (_saving || activeAreas.isEmpty) return;
    final draft = await Navigator.of(context).push<LifeAssessmentDraft>(
      MaterialPageRoute(
        builder: (_) => LifeAssessmentEditor(
          areas: activeAreas,
          initialAssessment: initialAssessment,
        ),
      ),
    );
    if (!mounted || draft == null) return;
    _pendingDraft = draft;
    _pendingOperationId = initialAssessment?.id ?? _uuid.v4();
    _pendingIsUpdate = initialAssessment != null;
    await _savePendingAssessment();
  }

  Future<void> _savePendingAssessment() async {
    final draft = _pendingDraft;
    final operationId = _pendingOperationId;
    if (_saving || draft == null || operationId == null) return;
    setState(() {
      _saving = true;
      _actionMessage = null;
    });
    try {
      if (_pendingIsUpdate) {
        await widget.repository.updateAssessment(
          assessmentId: operationId,
          draft: draft,
        );
      } else {
        await widget.repository.createAssessment(
          operationId: operationId,
          draft: draft,
        );
      }
      if (!mounted) return;
      _pendingDraft = null;
      _pendingOperationId = null;
      _pendingIsUpdate = false;
      _showMessage('Avaliação salva.');
      await _refresh();
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível confirmar. Tente novamente para verificar o salvamento.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAssessmentArchived(
    LifeAssessment assessment, {
    required bool archived,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(archived ? 'Arquivar avaliação?' : 'Restaurar avaliação?'),
        content: Text(
          archived
              ? 'A avaliação sairá da lista ativa. As notas e o histórico serão preservados.'
              : 'A avaliação voltará à lista ativa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(archived ? 'Arquivar' : 'Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.setAssessmentArchived(assessment.id, archived);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        _showMessage('Não foi possível atualizar a avaliação.', error: true);
      }
    }
  }

  Future<void> _renameArea(LifeArea area) async {
    final controller = TextEditingController(text: area.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar área'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null) return;
    final validation = validateLifeAreaName(name);
    if (validation != null) {
      _showMessage(validation, error: true);
      return;
    }
    try {
      await widget.repository.renameArea(area.id, name);
      if (mounted) {
        _showMessage('Área atualizada.');
        await _refresh();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Não foi possível editar essa área.', error: true);
      }
    }
  }

  Future<void> _archiveArea(LifeArea area, {required bool archived}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(archived ? 'Arquivar área?' : 'Restaurar área?'),
        content: Text(
          archived
              ? '“${area.name}” sairá das próximas avaliações. O histórico será preservado.'
              : '“${area.name}” voltará a aparecer nas avaliações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(archived ? 'Arquivar' : 'Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.setAreaArchived(area.id, archived);
      if (mounted) {
        _showMessage(archived ? 'Área arquivada.' : 'Área restaurada.');
        await _refresh();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Não foi possível atualizar essa área.', error: true);
      }
    }
  }

  Future<void> _reorderAreas(
    List<LifeArea> activeAreas,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = [...activeAreas];
    final area = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, area);
    try {
      await widget.repository.reorderAreas(
        reordered.map((area) => area.id).toList(growable: false),
      );
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        _showMessage('Não foi possível reordenar as áreas.', error: true);
        await _refresh();
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    setState(() {
      _actionMessage = message;
      _actionIsError = error;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vida'),
      actions: [
        TextButton(onPressed: widget.onSignOut, child: const Text('Sair')),
      ],
    ),
    body: FutureBuilder<_LifeSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(onRetry: _refresh);
        }
        final data = snapshot.data!;
        return RefreshIndicator(onRefresh: _refresh, child: _content(data));
      },
    ),
  );

  Widget _content(_LifeSnapshot data) {
    final activeAreas = data.areas.where((area) => !area.isArchived).toList();
    final archivedAreas = data.areas.where((area) => area.isArchived).toList();
    final activeAssessments = data.assessments
        .where((assessment) => !assessment.isArchived)
        .toList();
    final archivedAssessments = data.assessments
        .where((assessment) => assessment.isArchived)
        .toList();
    final selected = data.assessments.cast<LifeAssessment?>().firstWhere(
      (assessment) => assessment?.id == _selectedAssessmentId,
      orElse: () => activeAssessments.firstOrNull,
    );
    final selectedIndex = selected == null
        ? -1
        : data.assessments.indexWhere((item) => item.id == selected.id);
    final previous =
        selectedIndex >= 0 && selectedIndex + 1 < data.assessments.length
        ? data.assessments[selectedIndex + 1]
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('Entenda como está cada parte da sua vida.'),
            const SizedBox(height: 16),
            _assessmentSection(
              selected,
              previous,
              activeAssessments,
              data.areas,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || activeAreas.isEmpty
                  ? null
                  : () => _startAssessment(activeAreas),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_saving ? 'Salvando avaliação' : 'Nova avaliação'),
            ),
            if (archivedAssessments.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Avaliações arquivadas (${archivedAssessments.length})',
                ),
                children: [
                  for (final assessment in archivedAssessments)
                    ListTile(
                      title: Text(_formatDate(assessment.assessedOn)),
                      subtitle: Text(
                        'Média ${assessment.average.toStringAsFixed(1)}',
                      ),
                      onTap: () =>
                          setState(() => _selectedAssessmentId = assessment.id),
                      trailing: TextButton(
                        onPressed: () =>
                            _setAssessmentArchived(assessment, archived: false),
                        child: const Text('Restaurar'),
                      ),
                    ),
                ],
              ),
            if (_actionMessage case final message?) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: _actionIsError
                              ? Theme.of(context).colorScheme.error
                              : AppColors.mutedInk,
                        ),
                      ),
                    ),
                    if (_pendingDraft != null)
                      TextButton(
                        onPressed: _saving ? null : _savePendingAssessment,
                        child: const Text('Tentar de novo'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Áreas da vida',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  'Arraste para ordenar',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activeAreas.isEmpty)
              const _InlineNote(
                text: 'Todas as áreas estão arquivadas. Restaure uma para avaliar.',
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorderAreas(activeAreas, oldIndex, newIndex),
                children: [
                  for (var index = 0; index < activeAreas.length; index++)
                    _AreaRow(
                      key: ValueKey(activeAreas[index].id),
                      area: activeAreas[index],
                      score: _scoreFor(selected, activeAreas[index].id),
                      reorderIndex: index,
                      onRename: () => _renameArea(activeAreas[index]),
                      onArchive: () =>
                          _archiveArea(activeAreas[index], archived: true),
                    ),
                ],
              ),
            if (archivedAreas.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Arquivadas (${archivedAreas.length})'),
                children: [
                  for (final area in archivedAreas)
                    _AreaRow(
                      area: area,
                      score: _scoreFor(selected, area.id),
                      archived: true,
                      onRename: () => _renameArea(area),
                      onRestore: () => _archiveArea(area, archived: false),
                    ),
                ],
              ),
            if (_hasMoreAssessments) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadingMore
                    ? null
                    : () => _loadMoreAssessments(data),
                child: Text(
                  _loadingMore
                      ? 'Carregando histórico…'
                      : 'Ver avaliações anteriores',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assessmentSection(
    LifeAssessment? selected,
    LifeAssessment? previous,
    List<LifeAssessment> assessments,
    List<LifeArea> areas,
  ) {
    if (selected == null) {
      return const _InlineNote(
        text: 'Sua Roda da Vida começa com uma avaliação. Escolha as áreas que quer pontuar.',
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roda da Vida',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(selected.assessedOn),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      selected.average.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'média de ${selected.scores.where((score) => score.score != null).length} áreas',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'A nota representa sua percepção, não uma medida objetiva.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            ),
            const SizedBox(height: 8),
            Center(child: LifeWheelChart(scores: selected.scores)),
            for (final score in selected.scores)
              _ScoreRow(
                score: score,
                previous: _scoreFor(previous, score.areaId),
              ),
            if (selected.comment case final comment?) ...[
              const Divider(height: 24),
              Text(comment),
            ],
            if (selected.isArchived)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      _setAssessmentArchived(selected, archived: false),
                  child: const Text('Restaurar avaliação'),
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _startAssessment(
                            areas,
                            initialAssessment: selected,
                          ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar avaliação'),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () =>
                              _setAssessmentArchived(selected, archived: true),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Arquivar avaliação'),
                  ),
                ],
              ),
            if (assessments.length > 1) ...[
              const Divider(height: 24),
              Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final assessment in assessments)
                    ChoiceChip(
                      label: Text(
                        '${_formatDate(assessment.assessedOn)} · '
                        '${assessment.average.toStringAsFixed(1)}',
                      ),
                      selected: assessment.id == selected.id,
                      onSelected: (_) =>
                          setState(() => _selectedAssessmentId = assessment.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  int? _scoreFor(LifeAssessment? assessment, String areaId) {
    if (assessment == null) return null;
    for (final score in assessment.scores) {
      if (score.areaId == areaId) return score.score;
    }
    return null;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _LifeSnapshot {
  const _LifeSnapshot({required this.areas, required this.assessments});

  final List<LifeArea> areas;
  final List<LifeAssessment> assessments;
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.area,
    required this.score,
    required this.onRename,
    this.reorderIndex,
    this.onArchive,
    this.onRestore,
    this.archived = false,
    super.key,
  });

  final LifeArea area;
  final int? score;
  final VoidCallback onRename;
  final int? reorderIndex;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final bool archived;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: archived || reorderIndex == null
          ? const Icon(Icons.inventory_2_outlined)
          : ReorderableDragStartListener(
              index: reorderIndex!,
              child: const Icon(Icons.drag_handle_rounded),
            ),
      title: Text(area.name),
      subtitle: Text(score == null ? 'Sem avaliação' : '$score de 10'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opções de ${area.name}',
        onSelected: (value) {
          if (value == 'rename') onRename();
          if (value == 'archive') onArchive?.call();
          if (value == 'restore') onRestore?.call();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'rename', child: Text('Editar nome')),
          if (archived)
            const PopupMenuItem(value: 'restore', child: Text('Restaurar'))
          else
            const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
        ],
      ),
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score, required this.previous});

  final LifeAssessmentScore score;
  final int? previous;

  @override
  Widget build(BuildContext context) {
    String? delta;
    if (score.score != null && previous != null) {
      final difference = score.score! - previous!;
      delta = difference == 0
          ? 'Sem mudança'
          : '${difference > 0 ? '+' : ''}$difference vs. anterior';
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(score.areaName),
      subtitle: score.score == null
          ? const Text('Sem nota nesta avaliação')
          : score.needsAttention
          ? const Text('Marcada para atenção')
          : delta == null
          ? null
          : Text(delta),
      trailing: Text(score.score == null ? '—' : '${score.score}/10'),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppColors.mutedInk),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Não foi possível carregar suas áreas e avaliações.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
