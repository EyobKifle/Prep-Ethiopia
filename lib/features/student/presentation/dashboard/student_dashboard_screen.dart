import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_provider.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  bool _isLoading = true;
  List<SubjectLocal> _subjects = [];
  final Map<String, double> _subjectProgressMap = {};
  LessonLocal? _lastActiveLesson;
  StepLocal? _lastActiveStep;
  int _streakDays = 0;
  int _dueFlashcardsCount = 0;

  // Guest Specific
  List<GradeLocal> _allGrades = [];
  int _selectedGradeLevel = 9;
  List<TextbookLocal> _guestTextbooks = [];
  String? _downloadingTextbookUuid;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    final isar = ref.read(isarProvider);
    final auth = ref.read(authProvider);
    final isGuest = auth.user == null;

    if (isGuest) {
      _allGrades = await isar.gradeLocals.where().sortByLevel().findAll();
      if (auth.profile?.selectedGradeLevel != null) {
        _selectedGradeLevel = auth.profile!.selectedGradeLevel!;
      } else if (_allGrades.isNotEmpty) {
        _selectedGradeLevel = _allGrades.first.level;
      }
      await _loadGuestTextbooks();
    } else {
      // Fetch flashcards due for review
      _dueFlashcardsCount = await isar.userFlashcardLocals
          .where()
          .nextReviewAtLessThan(DateTime.now())
          .count();

      final gradeLevel = auth.profile?.selectedGradeLevel;
      if (gradeLevel != null) {
        // 1. Fetch current grade
        final grade = await isar.gradeLocals.filter().levelEqualTo(gradeLevel).findFirst();
        if (grade != null) {
          // 2. Fetch subjects for the grade
          final subjects = await isar.subjectLocals.filter().gradeUuidEqualTo(grade.uuid).findAll();
          _subjects = subjects;

          // 3. Compute progress for each subject
          for (final subject in subjects) {
            final progress = await _calculateSubjectProgress(isar, subject.uuid);
            _subjectProgressMap[subject.uuid] = progress;
          }

          // 4. Load last active lesson/step for "Continue Learning"
          await _loadLastActiveStep(isar, auth.user?.id);
        }
      }

      // 5. Calculate real streak from UserProgressLocal completion dates
      _streakDays = await _calculateStreak(isar);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGuestTextbooks() async {
    final isar = ref.read(isarProvider);
    final grade = await isar.gradeLocals.filter().levelEqualTo(_selectedGradeLevel).findFirst();
    if (grade != null) {
      final subjects = await isar.subjectLocals.filter().gradeUuidEqualTo(grade.uuid).findAll();
      final subjectUuids = subjects.map((s) => s.uuid).toList();
      if (subjectUuids.isNotEmpty) {
        _guestTextbooks = await isar.textbookLocals
            .filter()
            .anyOf(subjectUuids, (q, String uuid) => q.subjectUuidEqualTo(uuid))
            .findAll();
      } else {
        _guestTextbooks = [];
      }
    } else {
      _guestTextbooks = [];
    }
  }

  Future<void> _downloadTextbook(TextbookLocal textbook) async {
    final auth = ref.read(authProvider);
    final isGuest = auth.user == null;
    final isar = ref.read(isarProvider);

    if (isGuest) {
      final downloadedCount = await isar.textbookLocals.filter().isDownloadedEqualTo(true).count();
      if (downloadedCount >= 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must sign up to download more than 2 books.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    final api = ref.read(remoteApiServiceProvider);

    try {
      setState(() {
        _downloadingTextbookUuid = textbook.uuid;
        _downloadProgress = 0;
      });

      final appDocDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDocDir.path}/textbooks';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$dirPath/${textbook.uuid}.pdf';

      final bytes = await api.downloadFile(
        textbook.pdfUrl,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await isar.writeTxn(() async {
        textbook.isDownloaded = true;
        textbook.localPdfPath = filePath;
        textbook.updatedAt = DateTime.now();
        await isar.textbookLocals.put(textbook);
      });

      if (mounted) {
        setState(() {
          _downloadingTextbookUuid = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${textbook.title.getLocalized(context.currentLocale)} Downloaded'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadGuestTextbooks();
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingTextbookUuid = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<double> _calculateSubjectProgress(Isar isar, String subjectUuid) async {
    final units = await isar.unitLocals.filter().subjectUuidEqualTo(subjectUuid).findAll();
    if (units.isEmpty) return 0.0;

    int totalSteps = 0;
    int completedSteps = 0;

    for (final unit in units) {
      final lessons = await isar.lessonLocals.filter().unitUuidEqualTo(unit.uuid).findAll();
      for (final lesson in lessons) {
        final steps = await isar.stepLocals.filter().lessonUuidEqualTo(lesson.uuid).findAll();
        for (final step in steps) {
          totalSteps++;
          final progress = await isar.userProgressLocals
              .filter()
              .stepUuidEqualTo(step.uuid)
              .isCompletedEqualTo(true)
              .findFirst();
          if (progress != null) {
            completedSteps++;
          }
        }
      }
    }

    if (totalSteps == 0) return 0.0;
    return completedSteps / totalSteps;
  }

  Future<void> _loadLastActiveStep(Isar isar, String? userId) async {
    if (userId == null) return;
    
    final latestProgress = await isar.userProgressLocals
        .filter()
        .isCompletedEqualTo(true)
        .sortByUpdatedAtDesc()
        .findFirst();

    if (latestProgress != null) {
      final step = await isar.stepLocals.filter().uuidEqualTo(latestProgress.stepUuid).findFirst();
      if (step != null) {
        final lesson = await isar.lessonLocals.filter().uuidEqualTo(step.lessonUuid).findFirst();
        if (lesson != null) {
          _lastActiveStep = step;
          _lastActiveLesson = lesson;
        }
      }
    }
  }

  Future<int> _calculateStreak(Isar isar) async {
    final allProgress = await isar.userProgressLocals
        .filter()
        .isCompletedEqualTo(true)
        .completedAtIsNotNull()
        .sortByCompletedAtDesc()
        .findAll();

    if (allProgress.isEmpty) return 0;

    final completedDays = allProgress
        .where((p) => p.completedAt != null)
        .map((p) {
          final d = p.completedAt!.toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (completedDays.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final mostRecent = completedDays.first;
    if (mostRecent.isBefore(todayDate.subtract(const Duration(days: 1)))) return 0;

    int streak = 1;
    for (int i = 1; i < completedDays.length; i++) {
      final expected = completedDays[i - 1].subtract(const Duration(days: 1));
      if (completedDays[i] == expected) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isGuest = authState.user == null;

    if (!isGuest && authState.profile?.selectedGradeLevel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/onboarding');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: const CircularProgressIndicator()),
      );
    }

    final locale = context.currentLocale;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('appName')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/student/search'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isGuest) ...[
                _buildGuestBanner(context),
                const SizedBox(height: 24),
                _buildGradeSelector(context),
                const SizedBox(height: 24),
                _buildGuestTextbookList(context, locale),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.tr('welcome')}, ${authState.profile?.fullName ?? 'Student'}!',
                            style: AppTheme.getHeadingStyle(context: context, fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('welcomeSubtitle'),
                            style: AppTheme.getBodyStyle(context: context),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                          width: 1.0,
                        ),
                        borderRadius: AppTheme.borderRadius,
                        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('streakDays', arg: '$_streakDays'),
                            style: AppTheme.getHeadingStyle(context: context, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_lastActiveLesson != null && _lastActiveStep != null) ...[
                  _buildContinueLearningCard(context),
                  const SizedBox(height: 24),
                ],
                if (_dueFlashcardsCount > 0) ...[
                  _buildFlashcardAlert(context),
                  const SizedBox(height: 24),
                ],
                Text(
                  context.tr('navSubjects'),
                  style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
                ),
                const SizedBox(height: 16),
                _subjects.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            context.tr('emptyStateSubtitle'),
                            textAlign: TextAlign.center,
                            style: AppTheme.getBodyStyle(context: context),
                          ),
                        ),
                      )
                    : _buildSubjectGrid(context, locale),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Grade',
          style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _allGrades.map((grade) {
              final isSelected = grade.level == _selectedGradeLevel;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ChoiceChip(
                  label: Text('Grade ${grade.level}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedGradeLevel = grade.level;
                        _loadGuestTextbooks();
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Mode',
                  style: AppTheme.getHeadingStyle(context: context, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to save your progress and access all features.',
                  style: AppTheme.getBodyStyle(context: context, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(
              foregroundColor: theme.primaryColor,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestTextbookList(BuildContext context, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Textbooks',
          style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
        ),
        const SizedBox(height: 16),
        _guestTextbooks.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No textbooks available for this grade.'),
              ))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _guestTextbooks.length,
                itemBuilder: (context, index) {
                  final textbook = _guestTextbooks[index];
                  return _buildGuestTextbookCard(context, textbook, locale);
                },
              ),
      ],
    );
  }

  Widget _buildGuestTextbookCard(BuildContext context, TextbookLocal textbook, String locale) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDownloaded = textbook.isDownloaded;
    final isDownloading = _downloadingTextbookUuid == textbook.uuid;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isDownloaded ? 1 : 0,
      color: isDownloaded 
          ? (isDark ? AppTheme.darkSurface : AppTheme.lightSurface)
          : (isDark ? Colors.grey[900] : Colors.grey[200]),
      child: ListTile(
        onTap: isDownloaded ? () {
          context.push('/student/textbook/${textbook.uuid}');
        } : null,
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          Icons.book,
          size: 40,
          color: isDownloaded ? theme.primaryColor : Colors.grey,
        ),
        title: Text(
          textbook.title.getLocalized(locale),
          style: AppTheme.getHeadingStyle(context: context, fontSize: 16).copyWith(
            color: isDownloaded ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          isDownloaded ? 'Saved Offline' : 'Available for download',
          style: AppTheme.getBodyStyle(context: context, fontSize: 12).copyWith(
            color: isDownloaded ? Colors.green : Colors.grey,
          ),
        ),
        trailing: isDownloading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: _downloadProgress,
                  strokeWidth: 3,
                ),
              )
            : IconButton(
                icon: Icon(
                  isDownloaded ? Icons.check_circle : Icons.download,
                  color: isDownloaded ? Colors.green : theme.primaryColor,
                ),
                onPressed: isDownloaded ? null : () => _downloadTextbook(textbook),
              ),
      ),
    );
  }

  Widget _buildSubjectGrid(BuildContext context, String locale) {
    return LayoutBuilder(
      builder: (context, gridConstraints) {
        final crossAxisCount = gridConstraints.maxWidth >= 900
            ? 4
            : gridConstraints.maxWidth >= 600
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _subjects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (context, index) {
            final subject = _subjects[index];
            final progress = _subjectProgressMap[subject.uuid] ?? 0.0;
            return _buildSubjectCard(context, subject, progress, locale);
          },
        );
      },
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectLocal subject, double progress, String locale) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => context.push('/student/subject/${subject.uuid}'),
      borderRadius: AppTheme.borderRadius,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        width: 1.0,
                      ),
                      borderRadius: AppTheme.borderRadius,
                    ),
                    child: const Icon(Icons.book_outlined, size: 16),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTheme.getHeadingStyle(context: context, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                subject.name.getLocalized(locale),
                style: AppTheme.getHeadingStyle(context: context, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashcardAlert(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.style, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cards Due for Review',
                  style: AppTheme.getHeadingStyle(context: context, fontSize: 14),
                ),
                Text(
                  'You have $_dueFlashcardsCount flashcards ready to review.',
                  style: AppTheme.getBodyStyle(context: context, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/student/exercises'),
            child: const Text('Practice Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: AppTheme.borderRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('continueLearning').toUpperCase(),
                  style: AppTheme.getHeadingStyle(
                    context: context,
                    fontSize: 11,
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastActiveLesson!.title.getLocalized(context.currentLocale),
                  style: AppTheme.getHeadingStyle(
                    context: context,
                    fontSize: 18,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Step: ${_lastActiveStep!.title.getLocalized(context.currentLocale)}',
                  style: AppTheme.getBodyStyle(
                    context: context,
                    fontSize: 13,
                    color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              final stepType = _lastActiveStep!.type;
              if (stepType == StepType.read) {
                context.push('/student/lesson/${_lastActiveLesson!.uuid}/reading/${_lastActiveStep!.uuid}');
              } else if (stepType == StepType.quiz) {
                context.push('/student/lesson/${_lastActiveLesson!.uuid}/quiz/${_lastActiveStep!.uuid}');
              } else {
                context.push('/student/lesson/${_lastActiveLesson!.uuid}/flashcards/${_lastActiveStep!.uuid}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.black : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
            ),
            child: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
