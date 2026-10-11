import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class QuizQuestionEditorScreen extends ConsumerStatefulWidget {
  final String stepUuid;
  const QuizQuestionEditorScreen({super.key, required this.stepUuid});

  @override
  ConsumerState<QuizQuestionEditorScreen> createState() => _QuizQuestionEditorScreenState();
}

class _QuizQuestionEditorScreenState extends ConsumerState<QuizQuestionEditorScreen> {
  StepLocal? _step;
  List<QuizQuestionLocal> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);
    
    final step = await isar.stepLocals.where().uuidEqualTo(widget.stepUuid).findFirst();
    final questions = await isar.quizQuestionLocals
        .filter()
        .stepUuidEqualTo(widget.stepUuid)
        .isDeletedEqualTo(false)
        .findAll();

    if (mounted) {
      setState(() {
        _step = step;
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveQuestions() async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      for (var q in _questions) {
        q.isDirty = true;
        q.updatedAt = DateTime.now();
        await isar.quizQuestionLocals.put(q);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz questions saved and marked for sync')));
    }
  }

  void _addQuestion() {
    final newQuestion = QuizQuestionLocal()
      ..uuid = 'q_q_${DateTime.now().millisecondsSinceEpoch}'
      ..stepUuid = widget.stepUuid
      ..questionText = {'en': '', 'am': ''}
      ..options = ['', '', '', '']
      ..correctOptionIndex = 0
      ..explanation = {'en': '', 'am': ''}
      ..points = 1
      ..updatedAt = DateTime.now()
      ..isDirty = true;
    
    setState(() {
      _questions.add(newQuestion);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_step == null) return const Scaffold(body: Center(child: Text('Step not found')));

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Quiz: ${_step!.title.getLocalized(context.currentLocale)}'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveQuestions),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length + 1,
        itemBuilder: (context, index) {
          if (index == _questions.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: ElevatedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            );
          }
          return _buildQuestionEditor(_questions[index], index);
        },
      ),
    );
  }

  Widget _buildQuestionEditor(QuizQuestionLocal question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      final removed = _questions.removeAt(index);
                      _markQuestionDeleted(removed.uuid);
                    });
                  },
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Question Text (EN)'),
              maxLines: 2,
              onChanged: (val) {
                final texts = Map<String, String>.from(question.questionText);
                texts['en'] = val;
                question.questionText = texts;
              },
              controller: TextEditingController(text: question.questionText['en']),
            ),
            const SizedBox(height: 16),
            const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
            ...List.generate(4, (optIndex) => Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Option ${String.fromCharCode(65 + optIndex)}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final opts = List<String>.from(question.options);
                  opts[optIndex] = val;
                  question.options = opts;
                },
                controller: TextEditingController(text: question.options[optIndex]),
              ),
            )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: question.correctOptionIndex,
                    decoration: const InputDecoration(labelText: 'Correct Option', border: OutlineInputBorder()),
                    items: List.generate(4, (i) => DropdownMenuItem(value: i, child: Text('Option ${String.fromCharCode(65 + i)}'))),
                    onChanged: (val) => setState(() => question.correctOptionIndex = val ?? 0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Points', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => question.points = int.tryParse(val) ?? question.points,
                    controller: TextEditingController(text: question.points.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Explanation (EN)', border: OutlineInputBorder()),
              maxLines: 2,
              onChanged: (val) {
                final exps = Map<String, String>.from(question.explanation);
                exps['en'] = val;
                question.explanation = exps;
              },
              controller: TextEditingController(text: question.explanation['en']),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markQuestionDeleted(String uuid) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final q = await isar.quizQuestionLocals.where().uuidEqualTo(uuid).findFirst();
      if (q != null) {
        q.isDeleted = true;
        q.isDirty = true;
        q.updatedAt = DateTime.now();
        await isar.quizQuestionLocals.put(q);
      }
    });
  }
}
