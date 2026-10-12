import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class LessonQuizScreen extends ConsumerStatefulWidget {
  final String lessonUuid;
  final String stepUuid;
  const LessonQuizScreen({super.key, required this.lessonUuid, required this.stepUuid});

  @override
  ConsumerState<LessonQuizScreen> createState() => _LessonQuizScreenState();
}

class _LessonQuizScreenState extends ConsumerState<LessonQuizScreen> {
  List<QuizQuestionLocal> _questions = [];
  int _currentIndex = 0;
  final Map<String, int> _selectedAnswers = {}; // questionUuid -> selectedIndex
  bool _isSubmitted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final isar = ref.read(isarProvider);
    final questions = await isar.quizQuestionLocals
        .where()
        .stepUuidEqualTo(widget.stepUuid)
        .findAll();

    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  void _onOptionSelected(int index) {
    if (_isSubmitted) return;
    setState(() {
      _selectedAnswers[_questions[_currentIndex].uuid] = index;
    });
  }

  Future<void> _submitQuiz() async {
    int score = 0;
    for (var q in _questions) {
      if (_selectedAnswers[q.uuid] == q.correctOptionIndex) {
        score += q.points;
      }
    }
    int maxScore = _questions.fold(0, (sum, q) => sum + q.points);

    final isar = ref.read(isarProvider);
    final authState = ref.read(authProvider);
    final userId = authState.profile?.uuid ?? 'guest';

    final attempt = QuizAttemptLocal()
      ..uuid = 'qa_${userId}_${widget.stepUuid}_${DateTime.now().millisecondsSinceEpoch}'
      ..stepUuid = widget.stepUuid
      ..score = score
      ..maxScore = maxScore
      ..submittedAt = DateTime.now()
      ..answersJson = null // Could serialize _selectedAnswers if needed
      ..isDirty = true
      ..isDeleted = false
      ..updatedAt = DateTime.now();

    final progress = UserProgressLocal()
      ..uuid = 'up_${userId}_${widget.stepUuid}'
      ..stepUuid = widget.stepUuid
      ..isCompleted = true
      ..completedAt = DateTime.now()
      ..isDirty = true
      ..isDeleted = false
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.quizAttemptLocals.put(attempt);
      await isar.userProgressLocals.put(progress);
    });

    if (mounted) {
      setState(() => _isSubmitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: const CircularProgressIndicator()));
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('emptyStateTitle'))),
      );
    }

    if (_isSubmitted) {
      return _buildResultsView();
    }

    final question = _questions[_currentIndex];
    final selectedIndex = _selectedAnswers[question.uuid];

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('quizStep')} (${_currentIndex + 1}/${_questions.length})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 30),
            Text(
              question.questionText.getLocalized(context.currentLocale),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 30),
            ...List.generate(question.options.length, (index) {
              final isSelected = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _onOptionSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : null,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            question.options[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: selectedIndex == null
                ? null
                : () {
                    if (_currentIndex < _questions.length - 1) {
                      setState(() => _currentIndex++);
                    } else {
                      _submitQuiz();
                    }
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_currentIndex < _questions.length - 1 ? context.tr('next') : context.tr('submit')),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    int score = 0;
    for (var q in _questions) {
      if (_selectedAnswers[q.uuid] == q.correctOptionIndex) {
        score += q.points;
      }
    }
    int totalPoints = _questions.fold(0, (sum, q) => sum + q.points);
    double percentage = totalPoints > 0 ? (score / totalPoints) * 100 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('reviewAnswers')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20),
              child: Column(
                children: [
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr('score')}: $score / $totalPoints',
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._questions.map((q) {
            final userIndex = _selectedAnswers[q.uuid];
            final isCorrect = userIndex == q.correctOptionIndex;
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
                title: Text(
                  q.questionText.getLocalized(context.currentLocale),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOptionResult(context.tr('correctAnswer'), q.options[q.correctOptionIndex], Colors.green),
                        if (!isCorrect)
                          const SizedBox(height: 8),
                        if (!isCorrect)
                          _buildOptionResult('Your Answer', userIndex != null ? q.options[userIndex] : 'None', Colors.red),
                        const Divider(height: 32),
                        Text(context.tr('explanation'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          q.explanation.getLocalized(context.currentLocale),
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('finish')),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOptionResult(String label, String text, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
