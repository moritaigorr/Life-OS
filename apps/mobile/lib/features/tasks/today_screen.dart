import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../theme/app_theme.dart';
import 'create_task.dart';
import 'task.dart';
import 'task_repository.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final TaskRepository repository;
  final VoidCallback onSignOut;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _uuid = Uuid();
  final _titleController = TextEditingController();
  late Future<List<Task>> _tasks;
  String? _pendingOperationId;
  String? _pendingTitle;
  String? _saveMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tasks = widget.repository.listRecent();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _tasks = widget.repository.listRecent());
    await _tasks;
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;
    if (title.runes.length > 200) {
      setState(() => _saveMessage = 'Use de 1 a 200 caracteres.');
      return;
    }
    if (_pendingTitle != title || _pendingOperationId == null) {
      _pendingTitle = title;
      _pendingOperationId = _uuid.v4();
    }

    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    try {
      await CreateTask(widget.repository).call(title, _pendingOperationId!);
      if (!mounted) return;
      _pendingTitle = null;
      _pendingOperationId = null;
      _titleController.clear();
      setState(() => _saveMessage = 'Salva');
      try {
        await _refresh();
      } catch (_) {
        // The write was confirmed; a failed refresh is shown by FutureBuilder
        // and must not turn a successful save into an unsafe new retry.
      }
    } on InvalidTaskTitle {
      if (mounted) setState(() => _saveMessage = 'Use de 1 a 200 caracteres.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveMessage =
              'Não foi possível salvar. Confira a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Life OS'),
      actions: [
        TextButton(onPressed: widget.onSignOut, child: const Text('Sair')),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoje',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organize o que importa agora.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        maxLength: 200,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _createTask(),
                        onChanged: (_) {
                          if (_pendingTitle != _titleController.text.trim()) {
                            _pendingTitle = null;
                            _pendingOperationId = null;
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Nova tarefa',
                          counterText: '',
                          prefixIcon: Icon(Icons.add_task_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Salvar tarefa',
                      onPressed: _saving ? null : _createTask,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
              if (_saveMessage case final message?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: TextStyle(
                        color: message == 'Salva'
                            ? AppColors.mutedInk
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Task>>(
                  future: _tasks,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _StateMessage(
                        message: 'Não foi possível carregar suas tarefas.',
                        action: 'Tentar novamente',
                        onPressed: _refresh,
                      );
                    }
                    final tasks = snapshot.data ?? const <Task>[];
                    if (tasks.isEmpty) {
                      return const _StateMessage(
                        message:
                            'Sua lista está vazia. Adicione a primeira tarefa.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.radio_button_unchecked),
                          title: Text(tasks[index].title),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, this.action, this.onPressed});

  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}
