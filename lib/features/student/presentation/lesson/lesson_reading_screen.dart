import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_provider.dart';
import 'widgets/youtube_modal.dart';

class LessonReadingScreen extends ConsumerStatefulWidget {
  final String lessonUuid;
  final String stepUuid;
  const LessonReadingScreen({super.key, required this.lessonUuid, required this.stepUuid});

  @override
  ConsumerState<LessonReadingScreen> createState() => _LessonReadingScreenState();
}

class _LessonReadingScreenState extends ConsumerState<LessonReadingScreen> {
  StepLocal? _currentStep;
  List<StepLocal> _allSteps = [];
  bool _isLoading = true;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(LessonReadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepUuid != widget.stepUuid) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);
    
    // Load current step
    final step = await isar.stepLocals.where().uuidEqualTo(widget.stepUuid).findFirst();
    
    // Load all sibling steps for navigation
    final steps = await isar.stepLocals
        .where()
        .lessonUuidEqualTo(widget.lessonUuid)
        .sortBySequenceNumber()
        .findAll();

    // Check if current step is already completed
    final progress = await isar.userProgressLocals
        .where()
        .stepUuidEqualTo(widget.stepUuid)
        .findFirst();

    if (mounted) {
      setState(() {
        _currentStep = step;
        _allSteps = steps;
        _isCompleted = progress?.isCompleted ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsCompleted() async {
    if (_currentStep == null) return;
    
    final isar = ref.read(isarProvider);
    final authState = ref.read(authProvider);
    final userId = authState.profile?.uuid ?? 'guest';

    // Deterministic UUID for UserProgress: userId + stepUuid
    final progressUuid = 'up_${userId}_${widget.stepUuid}';

    final progress = UserProgressLocal()
      ..uuid = progressUuid
      ..stepUuid = widget.stepUuid
      ..isCompleted = true
      ..completedAt = DateTime.now()
      ..isDirty = true
      ..isDeleted = false
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.userProgressLocals.put(progress);
    });

    if (mounted) {
      setState(() => _isCompleted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('submitSuccess'))),
      );
    }
  }

  void _navigateToStep(StepLocal step) {
    String route = '';
    switch (step.type) {
      case StepType.read:
        route = '/student/lesson/${widget.lessonUuid}/reading/${step.uuid}';
        break;
      case StepType.quiz:
        route = '/student/lesson/${widget.lessonUuid}/quiz/${step.uuid}';
        break;
      case StepType.flashcardReview:
        route = '/student/lesson/${widget.lessonUuid}/flashcards/${step.uuid}';
        break;
    }
    
    if (route.isNotEmpty) {
      context.pushReplacement(route);
    }
  }

  void _showVideoModal() {
    if (_currentStep?.youtubeVideoId == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => YoutubeModal(videoId: _currentStep!.youtubeVideoId!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentStep == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('emptyStateTitle'))),
      );
    }

    final currentIndex = _allSteps.indexWhere((s) => s.uuid == widget.stepUuid);
    final prevStep = currentIndex > 0 ? _allSteps[currentIndex - 1] : null;
    final nextStep = currentIndex < _allSteps.length - 1 ? _allSteps[currentIndex + 1] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep!.title.getLocalized(context.currentLocale)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                children: [
                  Markdown(
                    data: _currentStep!.contentMarkdown.getLocalized(context.currentLocale),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    styleSheet: MarkdownStyleSheet(
                      p: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  
                  if (_currentStep!.youtubeVideoId != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: InkWell(
                        onTap: _showVideoModal,
                        borderRadius: AppTheme.borderRadius,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: AppTheme.borderRadius,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_circle_filled, color: Colors.red, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('watchVideo'),
                                      style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('watchVideoSubtitle'),
                                      style: AppTheme.getBodyStyle(context: context, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isCompleted ? null : _markAsCompleted,
                icon: Icon(_isCompleted ? Icons.check_circle : Icons.check_circle_outline),
                label: Text(_isCompleted ? context.tr('synced') : context.tr('submit')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/student/ai-tutor?lessonUuid=${widget.lessonUuid}');
        },
        icon: const Icon(Icons.psychology),
        label: const Text("Ask AI Tutor"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: prevStep != null ? () => _navigateToStep(prevStep) : null,
              icon: const Icon(Icons.arrow_back),
              label: Text(context.tr('back')),
            ),
            TextButton.icon(
              onPressed: nextStep != null ? () => _navigateToStep(nextStep) : null,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.tr('next')),
            ),
          ],
        ),
      ),
    );
  }
}
