import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  bool _isLoading = true;
  List<ParentStudentLinkLocal> _links = [];
  final Map<String, ProfileLocal?> _studentProfiles = {};
  final Map<String, Map<String, double>> _studentSubjectProgress = {}; // studentUuid -> {subjectName: progress}
  final Map<String, List<QuizAttemptLocal>> _studentRecentActivity = {};
  final Map<String, Map<String, double>> _studentSubjectAverages = {}; // studentUuid -> {subjectName: avgScore}
  final Map<String, List<String>> _studentWeaknesses = {};

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    final locale = context.currentLocale;
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);
    final auth = ref.read(authProvider);
    final parentUuid = auth.profile?.uuid;

    if (parentUuid == null) return;

    final links = await isar.parentStudentLinkLocals.where().parentUuidEqualTo(parentUuid).findAll();
    
    for (var link in links) {
      final sUuid = link.studentUuid;
      _studentProfiles[sUuid] = await isar.profileLocals.where().uuidEqualTo(sUuid).findFirst();
      
      // 1. Calculate Subject Progress
      final subjects = await isar.subjectLocals.where().findAll();
      final progressMap = <String, double>{};
      final averagesMap = <String, double>{};
      final weaknesses = <String>[];

      for (var sub in subjects) {
        final units = await isar.unitLocals.where().subjectUuidEqualTo(sub.uuid).findAll();
        int totalSteps = 0;
        int completedSteps = 0;
        
        List<int> scores = [];

        for (var unit in units) {
          final lessons = await isar.lessonLocals.where().unitUuidEqualTo(unit.uuid).findAll();
          for (var lesson in lessons) {
            final steps = await isar.stepLocals.where().lessonUuidEqualTo(lesson.uuid).findAll();
            totalSteps += steps.length;
            for (var step in steps) {
              final comp = await isar.userProgressLocals
                  .filter()
                  .stepUuidEqualTo(step.uuid)
                  .isCompletedEqualTo(true)
                  .findFirst();
              if (comp != null) completedSteps++;

              if (step.type == StepType.quiz) {
                final attempts = await isar.quizAttemptLocals
                    .filter()
                    .stepUuidEqualTo(step.uuid)
                    .findAll();
                for (var a in attempts) {
                  scores.add(((a.score / a.maxScore) * 100).toInt());
                }
              }
            }
          }
        }
        
        final subName = sub.name.getLocalized(locale);
        if (totalSteps > 0) progressMap[subName] = completedSteps / totalSteps;
        
        if (scores.isNotEmpty) {
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          averagesMap[subName] = avg;
          if (avg < 50) weaknesses.add(subName);
        }
      }

      _studentSubjectProgress[sUuid] = progressMap;
      _studentSubjectAverages[sUuid] = averagesMap;
      _studentWeaknesses[sUuid] = weaknesses;

      // 2. Recent Activity - Fetch all and sort in-memory to bypass missing Isar sort index generator
      final allAttempts = await isar.quizAttemptLocals.where().findAll();
      allAttempts.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      _studentRecentActivity[sUuid] = allAttempts.take(5).toList();
    }

    if (mounted) {
      setState(() {
        _links = links;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('parentDashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            onPressed: () => context.push('/parent/link'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _links.isEmpty 
            ? _buildEmptyState() 
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _links.length,
                itemBuilder: (context, index) => _buildChildCard(_links[index].studentUuid),
              ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.family_restroom, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(context.tr('noChildrenLinked'), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/parent/link'),
            child: Text(context.tr('addChild')),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(String sUuid) {
    final profile = _studentProfiles[sUuid];
    final progress = _studentSubjectProgress[sUuid] ?? {};
    final recent = _studentRecentActivity[sUuid] ?? [];
    final weaknesses = _studentWeaknesses[sUuid] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 2,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(profile?.fullName?[0] ?? 'S', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.fullName ?? 'Student', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Grade ${profile?.selectedGradeLevel ?? "N/A"}', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_events, color: Colors.orange),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Encouragement nudge sent!')));
                  },
                  tooltip: 'Send Congratulations',
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Syllabus Progress
                const Text('Syllabus Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...progress.entries.take(3).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13)),
                          Text('${(e.value * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: e.value, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                    ],
                  ),
                )),

                const Divider(height: 32),

                // Weakness Alerts
                if (weaknesses.isNotEmpty) ...[
                const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Needs Review', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: weaknesses.map((w) => Chip(
                      label: Text(w, style: const TextStyle(fontSize: 12, color: Colors.red)),
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      padding: EdgeInsets.zero,
                    )).toList(),
                  ),
                  const Divider(height: 32),
                ],

                // Recent Activity
                const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const Text('No recent activity recorded.', style: TextStyle(color: Colors.grey, fontSize: 13))
                else
                  ...recent.map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_turned_in_outlined, color: Colors.green),
                    title: const Text('Lesson Quiz', style: TextStyle(fontSize: 14)),
                    trailing: Text('${a.score}/${a.maxScore}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(a.submittedAt.toString().split(' ')[0], style: const TextStyle(fontSize: 12)),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
