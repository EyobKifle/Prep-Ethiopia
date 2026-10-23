// ignore_for_file: prefer_final_fields

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../features/auth/auth_provider.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectUuid;
  const SubjectDetailScreen({super.key, required this.subjectUuid});

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  SubjectLocal? _subject;
  List<TextbookLocal> _textbooks = [];
  List<UnitLocal> _units = [];
  Map<String, List<LessonLocal>> _unitLessonsMap = {};
  Map<String, List<StepLocal>> _lessonStepsMap = {};
  Map<String, bool> _stepCompletionMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubjectData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjectData() async {
    setState(() {
      _isLoading = true;
    });

    final isar = ref.read(isarProvider);
    final subject = await isar.subjectLocals.filter().uuidEqualTo(widget.subjectUuid).findFirst();

    if (subject != null) {
      _subject = subject;

      // 1. Load Textbooks
      _textbooks = await isar.textbookLocals.filter().subjectUuidEqualTo(widget.subjectUuid).findAll();

      // 2. Load Units
      _units = await isar.unitLocals.filter().subjectUuidEqualTo(widget.subjectUuid).sortBySequenceNumber().findAll();

      // 3. Load Lessons & Steps
      for (final unit in _units) {
        final lessons = await isar.lessonLocals.filter().unitUuidEqualTo(unit.uuid).sortBySequenceNumber().findAll();
        _unitLessonsMap[unit.uuid] = lessons;

        for (final lesson in lessons) {
          final steps = await isar.stepLocals.filter().lessonUuidEqualTo(lesson.uuid).sortBySequenceNumber().findAll();
          _lessonStepsMap[lesson.uuid] = steps;

          for (final step in steps) {
            final progress = await isar.userProgressLocals.filter().stepUuidEqualTo(step.uuid).findFirst();
            _stepCompletionMap[step.uuid] = progress?.isCompleted ?? false;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _downloadProgress = 0;
  String? _downloadingTextbookUuid;

  Future<void> _downloadTextbook(TextbookLocal textbook) async {
    final isar = ref.read(isarProvider);
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
            content: Text('${textbook.title.getLocalized(context.currentLocale)} ${context.tr('downloaded')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadSubjectData();
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

  Future<void> _deleteTextbook(TextbookLocal textbook) async {
    if (textbook.localPdfPath?.startsWith('assets/') ?? false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official curriculum textbooks are permanently available offline.')),
        );
      }
      return;
    }

    final isar = ref.read(isarProvider);
    
    try {
      if (textbook.localPdfPath != null) {
        final file = File(textbook.localPdfPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await isar.writeTxn(() async {
        textbook.isDownloaded = false;
        textbook.localPdfPath = null;
        textbook.updatedAt = DateTime.now();
        await isar.textbookLocals.put(textbook);
      });

      await _loadSubjectData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_subject == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('errorOccurred'))),
      );
    }

    final locale = context.currentLocale;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _subject!.name.getLocalized(locale),
          style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? Colors.white : Colors.black,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: '📖 ${context.tr('officialTextbooks')}'),
            Tab(text: '🎯 ${context.tr('structuredLearning')}'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTextbooksTab(context),
          _buildStructuredLearningTab(context),
        ],
      ),
    );
  }

  Widget _buildTextbooksTab(BuildContext context) {
    if (_textbooks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            context.tr('emptyStateSubtitle'),
            style: AppTheme.getBodyStyle(context: context),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _textbooks.length,
      itemBuilder: (context, index) {
        final textbook = _textbooks[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon or Cover image
                Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: AppTheme.borderRadius,
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textbook.title.getLocalized(context.currentLocale),
                        style: AppTheme.getHeadingStyle(context: context, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        textbook.pdfSizeBytes != null
                            ? '${(textbook.pdfSizeBytes! / 1024 / 1024).toStringAsFixed(1)} MB'
                            : 'Unknown size',
                        style: AppTheme.getBodyStyle(context: context, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (textbook.isDownloaded) ...[
                  if (textbook.localPdfPath?.startsWith('assets/') ?? false)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.offline_pin, color: Colors.green, size: 22),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteTextbook(textbook),
                      tooltip: context.tr('deleteTextbook'),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book, size: 18),
                    onPressed: () {
                      context.push('/student/textbook/${textbook.uuid}');
                    },
                    label: Text(context.tr('readStep')),
                  ),
                ] else ...[
                  if (_downloadingTextbookUuid == textbook.uuid)
                    SizedBox(
                      width: 100,
                      child: Column(
                        children: [
                          LinearProgressIndicator(value: _downloadProgress),
                          const SizedBox(height: 4),
                          Text('${(_downloadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => _downloadTextbook(textbook),
                      child: Text(context.tr('downloadTextbook')),
                    ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStructuredLearningTab(BuildContext context) {
    if (_units.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            context.tr('emptyStateSubtitle'),
            style: AppTheme.getBodyStyle(context: context),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final locale = context.currentLocale;

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _units.length,
      itemBuilder: (context, index) {
        final unit = _units[index];
        final lessons = _unitLessonsMap[unit.uuid] ?? [];

        return ExpansionTile(
          shape: const Border(),
          title: Text(
            unit.title.getLocalized(locale),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 15),
          ),
          subtitle: Text(
            unit.description.getLocalized(locale),
            style: AppTheme.getBodyStyle(context: context, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: lessons.map((lesson) {
            final steps = _lessonStepsMap[lesson.uuid] ?? [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      lesson.title.getLocalized(locale),
                      style: AppTheme.getHeadingStyle(context: context, fontSize: 14),
                    ),
                  ),
                  Row(
                    children: steps.map((step) {
                      final isCompleted = _stepCompletionMap[step.uuid] ?? false;
                      final type = step.type;

                      IconData iconData;
                      String stepText;
                      
                      switch (type) {
                        case StepType.read:
                          iconData = Icons.chrome_reader_mode_outlined;
                          stepText = context.tr('readStep');
                          break;
                        case StepType.quiz:
                          iconData = Icons.help_outline;
                          stepText = context.tr('quizStep');
                          break;
                        case StepType.flashcardReview:
                          iconData = Icons.style_outlined;
                          stepText = context.tr('flashcardStep');
                          break;
                      }

                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            // Navigate to active step
                            if (type == StepType.read) {
                              context.push('/student/lesson/${lesson.uuid}/reading/${step.uuid}');
                            } else if (type == StepType.quiz) {
                              context.push('/student/lesson/${lesson.uuid}/quiz/${step.uuid}');
                            } else {
                              context.push('/student/lesson/${lesson.uuid}/flashcards/${step.uuid}');
                            }
                          },
                          child: Card(
                            color: isCompleted
                                ? (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.02))
                                : Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    iconData,
                                    color: isCompleted ? AppTheme.successGreen : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stepText,
                                    style: AppTheme.getBodyStyle(context: context, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
