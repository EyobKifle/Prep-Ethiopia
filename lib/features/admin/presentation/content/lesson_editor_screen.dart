import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class LessonEditorScreen extends ConsumerStatefulWidget {
  final String lessonUuid;
  const LessonEditorScreen({super.key, required this.lessonUuid});

  @override
  ConsumerState<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends ConsumerState<LessonEditorScreen> {
  LessonLocal? _lesson;
  List<StepLocal> _steps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  Future<void> _loadLessonData() async {
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);
    
    final lesson = await isar.lessonLocals.where().uuidEqualTo(widget.lessonUuid).findFirst();
    final steps = await isar.stepLocals.where().lessonUuidEqualTo(widget.lessonUuid).sortBySequenceNumber().findAll();

    if (mounted) {
      setState(() {
        _lesson = lesson;
        _steps = steps;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLesson() async {
    if (_lesson == null) return;
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      _lesson!.isDirty = true;
      _lesson!.updatedAt = DateTime.now();
      await isar.lessonLocals.put(_lesson!);
      for (var step in _steps) {
        step.isDirty = true;
        step.updatedAt = DateTime.now();
        await isar.stepLocals.put(step);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson saved and marked for sync')));
    }
  }

  void _addStep(StepType type) {
    final newStep = StepLocal()
      ..uuid = 'step_${DateTime.now().millisecondsSinceEpoch}'
      ..lessonUuid = widget.lessonUuid
      ..sequenceNumber = _steps.length + 1
      ..title = {'en': 'New Step', 'am': 'አዲስ ደረጃ'}
      ..type = type
      ..contentMarkdown = {'en': '', 'am': ''}
      ..updatedAt = DateTime.now()
      ..isDirty = true;
    
    setState(() {
      _steps.add(newStep);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: const CircularProgressIndicator()));
    if (_lesson == null) return const Scaffold(body: Center(child: Text('Lesson not found')));

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Lesson: ${_lesson!.title.getLocalized(context.currentLocale)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveLesson,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildLessonGeneralInfo(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                PopupMenuButton<StepType>(
                  onSelected: _addStep,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: StepType.read, child: Text('Add Reading Step')),
                    const PopupMenuItem(value: StepType.quiz, child: Text('Add Quiz Step')),
                    const PopupMenuItem(value: StepType.flashcardReview, child: Text('Add Flashcard Step')),
                  ],
                  child: const Chip(label: Text('Add Step'), avatar: Icon(Icons.add)),
                ),
              ],
            ),
            const Divider(),
            ...List.generate(_steps.length, (index) => _buildStepEditor(_steps[index], index)),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonGeneralInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Lesson Title (EN)'),
              onChanged: (val) {
                final names = Map<String, String>.from(_lesson!.title);
                names['en'] = val;
                _lesson!.title = names;
              },
              controller: TextEditingController(text: _lesson!.title['en']),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Sequence Number'),
              keyboardType: TextInputType.number,
              onChanged: (val) => _lesson!.sequenceNumber = int.tryParse(val) ?? _lesson!.sequenceNumber,
              controller: TextEditingController(text: _lesson!.sequenceNumber.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepEditor(StepLocal step, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text('Step ${step.sequenceNumber}: ${step.title.getLocalized(context.currentLocale)} (${step.type.name})'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Step Title (EN)'),
                  onChanged: (val) {
                    final titles = Map<String, String>.from(step.title);
                    titles['en'] = val;
                    step.title = titles;
                  },
                  controller: TextEditingController(text: step.title['en']),
                ),
                if (step.type == StepType.read)
                  TextField(
                    decoration: const InputDecoration(labelText: 'Content (Markdown)'),
                    maxLines: 10,
                    onChanged: (val) {
                      final content = Map<String, String>.from(step.contentMarkdown);
                      content['en'] = val;
                      step.contentMarkdown = content;
                    },
                    controller: TextEditingController(text: step.contentMarkdown['en']),
                  ),
                if (step.type == StepType.quiz)
                   _buildQuizQuestionsInline(step),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          final removed = _steps.removeAt(index);
                          _markStepDeleted(removed.uuid);
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Remove Step', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markStepDeleted(String uuid) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final step = await isar.stepLocals.where().uuidEqualTo(uuid).findFirst();
      if (step != null) {
        step.isDeleted = true;
        step.isDirty = true;
        step.updatedAt = DateTime.now();
        await isar.stepLocals.put(step);
      }
    });
  }

  Widget _buildQuizQuestionsInline(StepLocal step) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text('This step contains interactive quiz questions.', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/admin/quiz-editor/${step.uuid}'),
          icon: const Icon(Icons.quiz),
          label: const Text('Manage Quiz Questions'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
        ),
      ],
    );
  }
}
