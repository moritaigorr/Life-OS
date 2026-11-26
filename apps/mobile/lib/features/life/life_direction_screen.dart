import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'life_area.dart';
import 'life_direction_repository.dart';
import 'life_goal.dart';
import 'life_onboarding.dart';

class LifeDirectionScreen extends StatefulWidget {
  const LifeDirectionScreen({
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final LifeDirectionRepository repository;
  final VoidCallback onSignOut;

  @override
  State<LifeDirectionScreen> createState() => _LifeDirectionScreenState();
}

class _LifeDirectionScreenState extends State<LifeDirectionScreen> {
  late Future<_DirectionSnapshot> _snapshot;
  final _visionController = TextEditingController();
  Timer? _visionSaveTimer;
  Future<void> _visionSaveQueue = Future<void>.value();
  LifeOnboardingState? _onboarding;
  _DirectionSnapshot? _loadedSnapshot;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  Future<_DirectionSnapshot> _load() async {
    await widget.repository.ensureDefaultAreas();
    final results = await Future.wait<Object?>([
      widget.repository.listAreas(),
      widget.repository.listGoals(includeArchived: true),
      widget.repository.getOnboardingState(),
    ]);
    final savedState = results[2] as LifeOnboardingState?;
    _onboarding = _onboarding ?? savedState;
    if (_visionController.text.isEmpty && savedState?.lifeVision != null) {
      _visionController.text = savedState!.lifeVision!;
    }
    final snapshot = _DirectionSnapshot(
      areas: results[0] as List<LifeArea>,
      goals: results[1] as List<LifeGoal>,
      onboarding: savedState,
    );
    _loadedSnapshot = snapshot;
    return snapshot;
  }

  Future<void> _refresh() async {
    setState(() {
      _errorMessage = null;
      _snapshot = _load();
    });
    await _snapshot;
  }

  @override
  void dispose() {
    _visionSaveTimer?.cancel();
    _visionController.dispose();
    super.dispose();
  }

  Future<void> _beginOnboarding() async {
    final current = _onboarding;
    final state = current == null
        ? const LifeOnboardingState(
            status: LifeOnboardingStatus.inProgress,
            currentStep: 0,
          )
        : current.status == LifeOnboardingStatus.completed
        ? LifeOnboardingState(
            status: LifeOnboardingStatus.inProgress,
            currentStep: 0,
            lifeVision: current.lifeVision,
          )
        : current.resume();
    await _saveOnboarding(state, showEditor: true);
  }

  Future<void> _saveOnboarding(
    LifeOnboardingState state, {
    required bool showEditor,
  }) async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveOnboardingState(state);
      if (!mounted) return;
      setState(() {
        _onboarding = state;
        _saving = false;
        _errorMessage = null;
      });
      if (!showEditor) await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage =
              'Não foi possível salvar. Confira a conexão e tente novamente.';
        });
      }
    }
  }

  void _scheduleVisionSave() {
    final current = _onboarding;
    if (current == null || current.currentStep != 0) return;
    _visionSaveTimer?.cancel();
    _visionSaveTimer = Timer(const Duration(milliseconds: 700), () {
      final vision = _visionController.text.trim();
      final state = LifeOnboardingState(
        status: LifeOnboardingStatus.inProgress,
        currentStep: 0,
        lifeVision: vision.isEmpty ? null : vision,
      );
      _visionSaveQueue = _visionSaveQueue
          .catchError((_) {})
          .then((_) => widget.repository.saveOnboardingState(state))
          .then((_) {
            if (mounted) _onboarding = state;
          })
          .catchError((_) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Não foi possível salvar sua visão agora. Tente novamente quando estiver online.';
              });
            }
          });
    });
  }

  Future<void> _continueOnboarding() async {
    final message = validateLifeVision(_visionController.text);
    if (message != null) {
      setState(() => _errorMessage = message);
      return;
    }
    _visionSaveTimer?.cancel();
    await _visionSaveQueue;
    final next =
        (_onboarding ??
                const LifeOnboardingState(
                  status: LifeOnboardingStatus.inProgress,
                  currentStep: 0,
                ))
            .nextStep(vision: _visionController.text);
    await _saveOnboarding(next, showEditor: true);
  }

  Future<void> _skipOnboarding() async {
    _visionSaveTimer?.cancel();
    await _visionSaveQueue;
    final current =
        _onboarding ??
        const LifeOnboardingState(
          status: LifeOnboardingStatus.inProgress,
          currentStep: 0,
        );
    final vision = _visionController.text.trim();
    final state = LifeOnboardingState(
      status: LifeOnboardingStatus.skipped,
      currentStep: current.currentStep,
      lifeVision: vision.isEmpty ? current.lifeVision : vision,
    );
    await _saveOnboarding(state, showEditor: false);
  }

  Future<void> _completeOnboarding() async {
    _visionSaveTimer?.cancel();
    await _visionSaveQueue;
    final state =
        (_onboarding ??
                const LifeOnboardingState(
                  status: LifeOnboardingStatus.inProgress,
                  currentStep: 1,
                ))
            .complete(vision: _visionController.text);
    await _saveOnboarding(state, showEditor: false);
  }

  Future<void> _openGoalEditor(
    _DirectionSnapshot data, {
    LifeGoal? goal,
    LifeGoalKind kind = LifeGoalKind.annual,
  }) async {
    final draft = await showDialog<LifeGoalDraft>(
      context: context,
      builder: (_) => _LifeGoalEditor(
        areas: data.areas,
        goals: data.goals,
        initialGoal: goal,
        initialKind: kind,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      if (goal == null) {
        await widget.repository.createGoal(draft);
      } else {
        await widget.repository.updateGoal(goal.id, draft);
      }
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível salvar a meta. Confira a conexão e tente novamente.';
        });
      }
    }
  }

  Future<void> _setGoalArchived(LifeGoal goal, {required bool archived}) async {
    final action = archived ? 'arquivar' : 'restaurar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(archived ? 'Arquivar meta?' : 'Restaurar meta?'),
        content: Text(
          archived
              ? 'A meta ficará fora da lista ativa. Seu histórico será preservado.'
              : 'A meta voltará à lista ativa.',
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
      await widget.repository.setGoalArchived(goal.id, archived);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Não foi possível $action esta meta. Tente novamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Direção'),
      actions: [
        TextButton(onPressed: widget.onSignOut, child: const Text('Sair')),
      ],
    ),
    body: FutureBuilder<_DirectionSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar suas metas.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _refresh,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _content(snapshot.data!),
        );
      },
    ),
  );

  Widget _content(_DirectionSnapshot data) {
    final state = _onboarding ?? data.onboarding;
    final activeGoals = data.goals.where((goal) => !goal.isArchived).toList();
    final archivedGoals = data.goals.where((goal) => goal.isArchived).toList();
    final showWizard = state?.status == LifeOnboardingStatus.inProgress;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text('Escolha uma direção que faça sentido para você.'),
        const SizedBox(height: 16),
        if (showWizard) _onboardingCard(state!) else _onboardingSummary(state),
        if (state?.lifeVision case final vision? when vision.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visão de vida',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(vision),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Metas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            PopupMenuButton<LifeGoalKind>(
              tooltip: 'Adicionar meta',
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (kind) => _openGoalEditor(data, kind: kind),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: LifeGoalKind.annual,
                  child: Text('Meta anual'),
                ),
                PopupMenuItem(
                  value: LifeGoalKind.quarterly,
                  child: Text('Meta trimestral'),
                ),
              ],
            ),
          ],
        ),
        if (shouldWarnForQuarterlyGoals(activeGoals)) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Você tem mais de três metas trimestrais ativas. Considere reduzir o foco para manter um plano viável.',
                ),
              ),
            ),
          ),
        ],
        if (activeGoals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nenhuma meta ativa ainda.'),
                  const SizedBox(height: 4),
                  Text(
                    'Comece com um resultado que você quer alcançar e como vai reconhecê-lo.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          )
        else
          for (final goal in activeGoals)
            _goalCard(data, goal, archived: false),
        if (archivedGoals.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Metas arquivadas (${archivedGoals.length})'),
            children: [
              for (final goal in archivedGoals)
                _goalCard(data, goal, archived: true),
            ],
          ),
        if (_errorMessage case final message?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }

  Widget _onboardingSummary(LifeOnboardingState? state) {
    final completed = state?.status == LifeOnboardingStatus.completed;
    final skipped = state?.status == LifeOnboardingStatus.skipped;
    final buttonLabel = completed
        ? 'Editar visão de vida'
        : skipped
        ? 'Retomar configuração'
        : 'Começar configuração';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              completed
                  ? 'Configuração concluída'
                  : 'Uma direção, no seu ritmo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              completed
                  ? 'Você pode revisar sua visão quando quiser.'
                  : skipped
                  ? 'Sua etapa ficou salva. Você pode continuar quando quiser.'
                  : 'Registre uma visão simples e escolha um primeiro foco. Você pode pular sem bloquear o uso do app.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : _beginOnboarding,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onboardingCard(LifeOnboardingState state) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Etapa ${state.currentStep + 1} de 2',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (state.currentStep == 0) ...[
            Text(
              'O que você quer preservar ou construir?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Uma frase já basta. Ela fica privada e pode ser editada depois.',
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('lifeVisionInput'),
              controller: _visionController,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Minha visão de vida',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => _scheduleVisionSave(),
            ),
            FilledButton(
              onPressed: _saving ? null : _continueOnboarding,
              child: const Text('Continuar'),
            ),
          ] else ...[
            Text(
              'Metas anuais e trimestrais',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Defina um resultado e um critério simples para acompanhar o avanço. Você pode ajustar tudo depois.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving || _loadedSnapshot == null
                  ? null
                  : () => _openGoalEditor(_loadedSnapshot!),
              child: const Text('Criar meta anual'),
            ),
            OutlinedButton(
              onPressed: _saving || _loadedSnapshot == null
                  ? null
                  : () => _openGoalEditor(
                      _loadedSnapshot!,
                      kind: LifeGoalKind.quarterly,
                    ),
              child: const Text('Criar meta trimestral'),
            ),
            FilledButton(
              onPressed: _saving ? null : _completeOnboarding,
              child: const Text('Concluir configuração'),
            ),
          ],
          TextButton(
            onPressed: _saving ? null : _skipOnboarding,
            child: const Text('Pular por agora'),
          ),
          if (_errorMessage case final message?) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _goalCard(
    _DirectionSnapshot data,
    LifeGoal goal, {
    required bool archived,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Text(_goalPeriodLabel(goal)),
          if (goal.lifeAreaName case final areaName?) Text('Área: $areaName'),
          const SizedBox(height: 6),
          Text(goal.successCriteria),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.progress / 100,
            semanticsLabel: 'Progresso de ${goal.title}',
            semanticsValue: '${goal.progress}%',
          ),
          const SizedBox(height: 4),
          Text('${goal.progress}% concluído'),
          Wrap(
            spacing: 8,
            children: [
              if (!archived)
                TextButton.icon(
                  onPressed: () => _openGoalEditor(data, goal: goal),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar meta'),
                ),
              TextButton.icon(
                onPressed: () => _setGoalArchived(goal, archived: !archived),
                icon: Icon(
                  archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
                label: Text(archived ? 'Restaurar meta' : 'Arquivar meta'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _goalPeriodLabel(LifeGoal goal) => switch (goal.kind) {
    LifeGoalKind.annual => 'Meta anual • ${goal.year}',
    LifeGoalKind.quarterly =>
      'Meta do ${goal.quarter}º trimestre • ${goal.year}',
  };
}

class _DirectionSnapshot {
  const _DirectionSnapshot({
    required this.areas,
    required this.goals,
    required this.onboarding,
  });

  final List<LifeArea> areas;
  final List<LifeGoal> goals;
  final LifeOnboardingState? onboarding;
}

class _LifeGoalEditor extends StatefulWidget {
  const _LifeGoalEditor({
    required this.areas,
    required this.goals,
    required this.initialKind,
    this.initialGoal,
  });

  final List<LifeArea> areas;
  final List<LifeGoal> goals;
  final LifeGoalKind initialKind;
  final LifeGoal? initialGoal;

  @override
  State<_LifeGoalEditor> createState() => _LifeGoalEditorState();
}

class _LifeGoalEditorState extends State<_LifeGoalEditor> {
  late LifeGoalKind _kind;
  late int _year;
  int? _quarter;
  late String _yearValue;
  int _progress = 0;
  String? _areaId;
  String? _parentGoalId;
  String? _error;
  late final TextEditingController _titleController;
  late final TextEditingController _criteriaController;

  @override
  void initState() {
    super.initState();
    final goal = widget.initialGoal;
    _kind = goal?.kind ?? widget.initialKind;
    _year = goal?.year ?? DateTime.now().year;
    _yearValue = '$_year';
    _quarter = goal?.quarter ?? ((DateTime.now().month - 1) ~/ 3 + 1);
    _progress = goal?.progress ?? 0;
    _areaId = goal?.lifeAreaId;
    _parentGoalId = goal?.parentGoalId;
    _titleController = TextEditingController(text: goal?.title);
    _criteriaController = TextEditingController(text: goal?.successCriteria);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _criteriaController.dispose();
    super.dispose();
  }

  void _save() {
    final parsedYear = int.tryParse(_yearValue);
    if (parsedYear == null) {
      setState(() => _error = 'Informe um ano válido.');
      return;
    }
    _year = parsedYear;
    final draft = LifeGoalDraft(
      kind: _kind,
      year: _year,
      quarter: _kind == LifeGoalKind.quarterly ? _quarter : null,
      title: _titleController.text,
      successCriteria: _criteriaController.text,
      progress: _progress,
      lifeAreaId: _areaId,
      parentGoalId: _kind == LifeGoalKind.quarterly ? _parentGoalId : null,
    );
    final error = validateLifeGoalDraft(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialGoal == null ? 'Nova meta' : 'Editar meta'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<LifeGoalKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Período'),
              items: const [
                DropdownMenuItem(
                  value: LifeGoalKind.annual,
                  child: Text('Anual'),
                ),
                DropdownMenuItem(
                  value: LifeGoalKind.quarterly,
                  child: Text('Trimestral'),
                ),
              ],
              onChanged: (kind) => setState(() {
                _kind = kind ?? LifeGoalKind.annual;
                if (_kind == LifeGoalKind.annual) _parentGoalId = null;
              }),
            ),
            TextFormField(
              initialValue: _yearValue,
              decoration: const InputDecoration(labelText: 'Ano'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _yearValue = value;
                final year = int.tryParse(value);
                if (year != null) setState(() => _year = year);
              },
            ),
            if (_kind == LifeGoalKind.quarterly)
              DropdownButtonFormField<int>(
                initialValue: _quarter,
                decoration: const InputDecoration(labelText: 'Trimestre'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1º trimestre')),
                  DropdownMenuItem(value: 2, child: Text('2º trimestre')),
                  DropdownMenuItem(value: 3, child: Text('3º trimestre')),
                  DropdownMenuItem(value: 4, child: Text('4º trimestre')),
                ],
                onChanged: (value) => setState(() => _quarter = value),
              ),
            if (_kind == LifeGoalKind.quarterly)
              DropdownButtonFormField<String?>(
                initialValue: _parentGoalId,
                decoration: const InputDecoration(
                  labelText: 'Objetivo anual (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem vínculo'),
                  ),
                  for (final goal in widget.goals.where(
                    (goal) =>
                        !goal.isArchived &&
                        goal.kind == LifeGoalKind.annual &&
                        goal.year == _year,
                  ))
                    DropdownMenuItem(value: goal.id, child: Text(goal.title)),
                ],
                onChanged: (value) => setState(() => _parentGoalId = value),
              ),
            DropdownButtonFormField<String?>(
              initialValue: _areaId,
              decoration: const InputDecoration(
                labelText: 'Área da vida (opcional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sem área'),
                ),
                for (final area in widget.areas)
                  DropdownMenuItem(value: area.id, child: Text(area.name)),
              ],
              onChanged: (value) => setState(() => _areaId = value),
            ),
            TextField(
              key: const Key('goalTitleInput'),
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              key: const Key('goalCriteriaInput'),
              controller: _criteriaController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Como vou saber que concluí?',
                alignLabelWithHint: true,
              ),
            ),
            Text('Progresso: $_progress%'),
            Slider(
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_progress%',
              value: _progress.toDouble(),
              onChanged: (value) => setState(() => _progress = value.round()),
            ),
            if (_error case final message?)
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Salvar')),
    ],
  );
}
