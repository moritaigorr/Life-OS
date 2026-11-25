import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import 'life_area.dart';
import 'life_assessment.dart';

class LifeAssessmentEditor extends StatefulWidget {
  const LifeAssessmentEditor({required this.areas, super.key});

  final List<LifeArea> areas;

  @override
  State<LifeAssessmentEditor> createState() => _LifeAssessmentEditorState();
}

class _LifeAssessmentEditorState extends State<LifeAssessmentEditor> {
  final _commentController = TextEditingController();
  final Map<String, int> _scores = {};
  final Set<String> _needsAttention = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleArea(String areaId, bool selected) {
    setState(() {
      if (selected) {
        _scores[areaId] = 5;
      } else {
        _scores.remove(areaId);
        _needsAttention.remove(areaId);
      }
    });
  }

  void _save() {
    if (_scores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avalie pelo menos uma área.')),
      );
      return;
    }
    final comment = _commentController.text.trim();
    Navigator.of(context).pop(
      LifeAssessmentDraft(
        assessedOn: DateUtils.dateOnly(DateTime.now()),
        comment: comment.isEmpty ? null : comment,
        scores: [
          for (final area in widget.areas)
            if (_scores[area.id] case final score?)
              LifeScoreInput(
                areaId: area.id,
                score: score,
                needsAttention: _needsAttention.contains(area.id),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nova avaliação')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                'Como você percebe cada área hoje?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'A nota é subjetiva. Áreas sem nota não entram na média.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 16),
              for (final area in widget.areas) _areaCard(area),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: FilledButton(
        onPressed: _save,
        child: const Text('Salvar avaliação'),
      ),
    ),
  );

  Widget _areaCard(LifeArea area) {
    final score = _scores[area.id];
    final isSelected = score != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(area.name),
              subtitle: Text(isSelected ? 'Nota $score de 10' : 'Sem nota'),
              value: isSelected,
              onChanged: (value) => _toggleArea(area.id, value ?? false),
            ),
            Slider(
              min: 0,
              max: 10,
              divisions: 10,
              label: isSelected ? '$score de 10' : null,
              value: (score ?? 0).toDouble(),
              onChanged: isSelected
                  ? (value) => setState(() => _scores[area.id] = value.round())
                  : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Precisa de atenção'),
              value: _needsAttention.contains(area.id),
              onChanged: isSelected
                  ? (value) => setState(() {
                      if (value ?? false) {
                        _needsAttention.add(area.id);
                      } else {
                        _needsAttention.remove(area.id);
                      }
                    })
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
