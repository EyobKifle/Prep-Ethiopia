import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/fast_hash.dart';

class AnswerReviewScreen extends ConsumerStatefulWidget {
  const AnswerReviewScreen({super.key});

  @override
  ConsumerState<AnswerReviewScreen> createState() => _AnswerReviewScreenState();
}

class _AnswerReviewScreenState extends ConsumerState<AnswerReviewScreen> {
  List<QuizAttemptLocal> _quizAttempts = [];
  List<WorksheetAttemptLocal> _worksheetAttempts = [];
  Map<String, String> _stepTitles = {};
  Map<String, String> _worksheetTitles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarProvider);
    
    final qAttempts = await isar.quizAttemptLocals.where().sortBySubmittedAtDesc().findAll();
    final wAttempts = await isar.worksheetAttemptLocals.where().sortBySubmittedAtDesc().findAll();

    // Fetch titles for quizzes
    final stepUuids = qAttempts.map((a) => a.stepUuid).toSet().toList();
    final steps = await isar.stepLocals.getAll(stepUuids.map(fastHash).toList());
    
    if (!mounted) return;
    final currentLocale = context.currentLocale;
    
    final sTitles = {
      for (var s in steps.whereType<StepLocal>()) 
        s.uuid: s.title.getLocalized(currentLocale)
    };

    // Fetch titles for worksheets
    final wsUuids = wAttempts.map((a) => a.worksheetUuid).toSet().toList();
    final worksheets = await isar.worksheetLocals.getAll(wsUuids.map(fastHash).toList());
    final wTitles = {
      for (var w in worksheets.whereType<WorksheetLocal>()) 
        w.uuid: w.title.getLocalized(currentLocale)
    };

    if (mounted) {
      setState(() {
        _quizAttempts = qAttempts;
        _worksheetAttempts = wAttempts;
        _stepTitles = sTitles;
        _worksheetTitles = wTitles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('reviewAnswers')),
          bottom: TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: '${context.tr('quizStep')}s'),
              Tab(text: context.tr('worksheets')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: const CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAttemptsList(
                    attempts: _quizAttempts,
                    titles: _stepTitles,
                    isQuiz: true,
                  ),
                  _buildAttemptsList(
                    attempts: _worksheetAttempts,
                    titles: _worksheetTitles,
                    isQuiz: false,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAttemptsList({
    required List<dynamic> attempts,
    required Map<String, String> titles,
    required bool isQuiz,
  }) {
    if (attempts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              context.tr('emptyStateSubtitle'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: attempts.length,
      itemBuilder: (context, index) {
        final attempt = attempts[index];
        final uuid = isQuiz ? attempt.stepUuid : attempt.worksheetUuid;
        
        return _buildAttemptCard(
          title: titles[uuid] ?? (isQuiz ? 'Quiz' : 'Worksheet'),
          score: attempt.score,
          maxScore: attempt.maxScore,
          date: attempt.submittedAt,
        );
      },
    );
  }

  Widget _buildAttemptCard({
    required String title,
    required int score,
    required int maxScore,
    required DateTime date,
  }) {
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0;
    
    Color statusColor;
    if (percentage >= 60) {
      statusColor = Colors.green;
    } else if (percentage >= 40) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(date),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score / $maxScore',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
