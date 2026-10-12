import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class WorksheetExerciseScreen extends ConsumerStatefulWidget {
  final String worksheetUuid;
  const WorksheetExerciseScreen({super.key, required this.worksheetUuid});

  @override
  ConsumerState<WorksheetExerciseScreen> createState() => _WorksheetExerciseScreenState();
}

class _WorksheetExerciseScreenState extends ConsumerState<WorksheetExerciseScreen> {
  List<WorksheetQuestionLocal> _questions = [];
  int _currentIndex = 0;
  final Map<String, int> _selectedAnswers = {};
  bool _isSubmitted = false;
  bool _isLoading = true;
  
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isSubmitted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarProvider);
    final questions = await isar.worksheetQuestionLocals
        .where()
        .worksheetUuidEqualTo(widget.worksheetUuid)
        .sortBySequenceNumber()
        .findAll();

    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    _timer?.cancel();
    
    int score = 0;
    for (var q in _questions) {
      if (_selectedAnswers[q.uuid] == q.correctOptionIndex) {
        score++;
      }
    }

    final isar = ref.read(isarProvider);
    final authState = ref.read(authProvider);
    final userId = authState.profile?.uuid ?? 'guest';

    final attempt = WorksheetAttemptLocal()
      ..uuid = 'wa_${userId}_${widget.worksheetUuid}_${DateTime.now().millisecondsSinceEpoch}'
      ..userUuid = userId
      ..worksheetUuid = widget.worksheetUuid
      ..score = score
      ..maxScore = _questions.length
      ..answersJson = jsonEncode(_selectedAnswers)
      ..submittedAt = DateTime.now()
      ..isDirty = true
      ..isDeleted = false
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.worksheetAttemptLocals.put(attempt);
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
        title: Text(context.tr('worksheets')),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Theme.of(context).primaryColor),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_elapsedSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              question.questionText.getLocalized(context.currentLocale),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 32),
            ...List.generate(question.options.length, (index) {
              final isSelected = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedAnswers[question.uuid] = index);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            question.options[index],
                            style: TextStyle(
                              fontSize: 17,
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
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: selectedIndex == null
                ? null
                : () {
                    if (_currentIndex < _questions.length - 1) {
                      setState(() => _currentIndex++);
                    } else {
                      _submit();
                    }
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              _currentIndex < _questions.length - 1 ? context.tr('next') : context.tr('submit'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    int score = 0;
    for (var q in _questions) {
      if (_selectedAnswers[q.uuid] == q.correctOptionIndex) {
        score++;
      }
    }
    double percentage = (_questions.isNotEmpty) ? (score / _questions.length) * 100 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('reviewAnswers')), 
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24),
              child: Column(
                children: [
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr('score')}: $score / ${_questions.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Time Taken: ${_formatTime(_elapsedSeconds)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ..._questions.map((q) {
            final userIndex = _selectedAnswers[q.uuid];
            final isCorrect = userIndex == q.correctOptionIndex;
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
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
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResultRow(context.tr('correctAnswer'), q.options[q.correctOptionIndex], Colors.green),
                        if (!isCorrect)
                          const SizedBox(height: 12),
                        if (!isCorrect)
                          _buildResultRow('Your Answer', userIndex != null ? q.options[userIndex] : 'None', Colors.red),
                        const Divider(height: 40),
                        Text(
                          context.tr('explanation'), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          q.explanation.getLocalized(context.currentLocale),
                          style: TextStyle(height: 1.5, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              context.tr('finish'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String text, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
