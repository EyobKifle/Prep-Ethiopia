import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../core/database/isar_models.dart';
import '../../core/database/isar_provider.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/remote_api_service.dart';

import '../auth/auth_provider.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final int pendingItemsCount;
  final DateTime? lastSyncedAt;

  const SyncState({
    required this.status,
    this.message,
    this.pendingItemsCount = 0,
    this.lastSyncedAt,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    int? pendingItemsCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      pendingItemsCount: pendingItemsCount ?? this.pendingItemsCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Isar _isar;
  final Ref _ref;

  SyncNotifier(this._isar, this._ref) : super(const SyncState(status: SyncStatus.idle)) {
    _ref.listen(connectivityProvider, (previous, next) {
      if (next == ConnectionStatus.online) {
        triggerSync();
      }
    });

    _calculatePendingItems();
  }

  Future<void> _calculatePendingItems() async {
    try {
      final progressCount = await _isar.userProgressLocals.filter().isDirtyEqualTo(true).count();
      final quizCount = await _isar.quizAttemptLocals.filter().isDirtyEqualTo(true).count();
      final examCount = await _isar.examAttemptLocals.filter().isDirtyEqualTo(true).count();
      final flashcardCount = await _isar.userFlashcardLocals.filter().isDirtyEqualTo(true).count();
      final profileCount = await _isar.profileLocals.filter().isDirtyEqualTo(true).count();
      final worksheetCount = await _isar.worksheetAttemptLocals.filter().isDirtyEqualTo(true).count();
      final linkCount = await _isar.parentStudentLinkLocals.filter().isDirtyEqualTo(true).count();
      final noteCount = await _isar.textbookNoteLocals.filter().isDirtyEqualTo(true).count();
    final highlightCount = await _isar.textbookHighlightLocals.filter().isDirtyEqualTo(true).count();
    final flagCount = await _isar.featureFlagLocals.filter().isDirtyEqualTo(true).count();
    final aiChatCount = await _isar.aiChatLocals.filter().isDirtyEqualTo(true).count();
    final aiMessageCount = await _isar.aiMessageLocals.filter().isDirtyEqualTo(true).count();

    // Admin curriculum items
    final gradeCount = await _isar.gradeLocals.filter().isDirtyEqualTo(true).count();
    final subjectCount = await _isar.subjectLocals.filter().isDirtyEqualTo(true).count();
    final unitCount = await _isar.unitLocals.filter().isDirtyEqualTo(true).count();
    final lessonCount = await _isar.lessonLocals.filter().isDirtyEqualTo(true).count();
    final stepCount = await _isar.stepLocals.filter().isDirtyEqualTo(true).count();

    state = state.copyWith(
      pendingItemsCount: progressCount +
          quizCount +
          examCount +
          flashcardCount +
          profileCount +
          worksheetCount +
          linkCount +
          noteCount +
          highlightCount +
          flagCount +
          aiChatCount +
          aiMessageCount +
          gradeCount +
          subjectCount +
          unitCount +
          lessonCount +
          stepCount,
    );
    } catch (_) {
      // Silently ignore initial count errors; sync will recalculate on next run
    }
  }

  Future<void> triggerSync({ProfileLocal? profileOverride}) async {
    final auth = _ref.read(authProvider);
    final syncProfile = profileOverride ?? auth.profile;
    if (auth.user == null) return;

    final connectivity = _ref.read(connectivityProvider);
    if (connectivity == ConnectionStatus.offline) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'No internet connection. Sync paused.',
      );
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing);

    try {
      final api = _ref.read(remoteApiServiceProvider);
      final auth = _ref.read(authProvider);
      if (auth.user != null) {
        api.setAuthToken(auth.user!.token);
      }

      // 1) PUSH: User Progress
      await _pushUserProgress(api, auth.user!.id);

      // 2) PUSH: Admin Curriculum (if applicable)
      if (syncProfile?.role == 'admin') {
        await _pushCurriculum(api);
      }

      // 3) PULL: Remote feature flags
      final featureFlags = await api.fetchFeatureFlags();
      await _isar.writeTxn(() async {
        for (final item in featureFlags) {
          final name = item.name;
          final existing = await _isar.featureFlagLocals.filter().keyEqualTo(name).findFirst();
          final flag = existing ?? FeatureFlagLocal()..key = name;
          flag.description = ''; 
          flag.isEnabled = item.enabled;
          flag.updatedAt = DateTime.now();
          await _isar.featureFlagLocals.put(flag);
        }
      });

      // 4) PULL: Incremental Curriculum
      final since = state.lastSyncedAt ?? DateTime.now().subtract(const Duration(days: 30));
      final curriculum = await api.fetchCurriculumIncremental(
        since: since,
        gradeLevel: syncProfile?.selectedGradeLevel,
      );
      await _pullCurriculum(curriculum);

      _calculatePendingItems();
      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncedAt: DateTime.now(),
        message: 'Sync completed successfully.',
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  Future<void> _pushUserProgress(RemoteApiService api, String userId) async {
    final dirtyProgress = await _isar.userProgressLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyQuizzes = await _isar.quizAttemptLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyExams = await _isar.examAttemptLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyFlashcards = await _isar.userFlashcardLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyProfiles = await _isar.profileLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyWorksheets = await _isar.worksheetAttemptLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyLinks = await _isar.parentStudentLinkLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyNotes = await _isar.textbookNoteLocals.filter().isDirtyEqualTo(true).findAll();
    final dirtyHighlights = await _isar.textbookHighlightLocals.filter().isDirtyEqualTo(true).findAll();

    if (dirtyProgress.isEmpty &&
        dirtyQuizzes.isEmpty &&
        dirtyExams.isEmpty &&
        dirtyFlashcards.isEmpty &&
        dirtyProfiles.isEmpty &&
        dirtyWorksheets.isEmpty &&
        dirtyLinks.isEmpty &&
        dirtyNotes.isEmpty &&
        dirtyHighlights.isEmpty) {
      return;
    }

    await api.pushUserProgress(
      userId: userId,
      userProgress: dirtyProgress.map((e) => {
        'uuid': e.uuid,
        'step_uuid': e.stepUuid,
        'is_completed': e.isCompleted,
        'completed_at': e.completedAt?.toIso8601String(),
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      quizAttempts: dirtyQuizzes.map((e) => {
        'uuid': e.uuid,
        'step_uuid': e.stepUuid,
        'score': e.score,
        'max_score': e.maxScore,
        'submitted_at': e.submittedAt.toIso8601String(),
        'answers_json': e.answersJson,
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      examAttempts: dirtyExams.map((e) => {
        'uuid': e.uuid,
        'exam_uuid': e.examUuid,
        'score': e.score,
        'max_score': e.maxScore,
        'duration_spent_seconds': e.durationSpentSeconds,
        'submitted_at': e.submittedAt.toIso8601String(),
        'answers_json': e.answersJson,
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      userFlashcards: dirtyFlashcards.map((e) => {
        'uuid': e.uuid,
        'card_template_uuid': e.cardTemplateUuid,
        'ease_factor': e.easeFactor,
        'interval_days': e.intervalDays,
        'repetitions': e.repetitions,
        'next_review_at': e.nextReviewAt.toIso8601String(),
        'last_reviewed_at': e.lastReviewedAt?.toIso8601String(),
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      profiles: dirtyProfiles.map((e) => {
        'uuid': e.uuid,
        'role': e.role,
        'full_name': e.fullName,
        'phone_number': e.phoneNumber,
        'preferred_language': e.preferredLanguage,
        'selected_grade_level': e.selectedGradeLevel,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      worksheetAttempts: dirtyWorksheets.map((e) => {
        'uuid': e.uuid,
        'user_uuid': e.userUuid,
        'worksheet_uuid': e.worksheetUuid,
        'score': e.score,
        'max_score': e.maxScore,
        'answers_json': e.answersJson,
        'submitted_at': e.submittedAt.toIso8601String(),
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      parentStudentLinks: dirtyLinks.map((e) => {
        'uuid': e.uuid,
        'parent_uuid': e.parentUuid,
        'student_uuid': e.studentUuid,
        'link_code': e.linkCode,
        'linked_at': e.linkedAt.toIso8601String(),
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      textbookNotes: dirtyNotes.map((e) => {
        'uuid': e.uuid,
        'textbook_uuid': e.textbookUuid,
        'user_uuid': e.userUuid,
        'page_number': e.pageNumber,
        'dx': e.dx,
        'dy': e.dy,
        'content': e.content,
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
      textbookHighlights: dirtyHighlights.map((e) => {
        'uuid': e.uuid,
        'textbook_uuid': e.textbookUuid,
        'user_uuid': e.userUuid,
        'page_number': e.pageNumber,
        'selected_text': e.selectedText,
        'color_hex': e.colorHex,
        'bounds_json': e.boundsJson,
        'is_deleted': e.isDeleted,
        'updated_at': e.updatedAt.toIso8601String(),
      }).toList(),
    );

    await _isar.writeTxn(() async {
      for (var p in dirtyProgress) {
        p.isDirty = false;
      }
      await _isar.userProgressLocals.putAll(dirtyProgress);
      for (var q in dirtyQuizzes) {
        q.isDirty = false;
      }
      await _isar.quizAttemptLocals.putAll(dirtyQuizzes);
      for (var ex in dirtyExams) {
        ex.isDirty = false;
      }
      await _isar.examAttemptLocals.putAll(dirtyExams);
      for (var f in dirtyFlashcards) {
        f.isDirty = false;
      }
      await _isar.userFlashcardLocals.putAll(dirtyFlashcards);
      for (var pr in dirtyProfiles) {
        pr.isDirty = false;
      }
      await _isar.profileLocals.putAll(dirtyProfiles);
      for (var w in dirtyWorksheets) {
        w.isDirty = false;
      }
      await _isar.worksheetAttemptLocals.putAll(dirtyWorksheets);
      for (var l in dirtyLinks) {
        l.isDirty = false;
      }
      await _isar.parentStudentLinkLocals.putAll(dirtyLinks);
      for (var n in dirtyNotes) {
        n.isDirty = false;
      }
      await _isar.textbookNoteLocals.putAll(dirtyNotes);
      for (var h in dirtyHighlights) {
        h.isDirty = false;
      }
      await _isar.textbookHighlightLocals.putAll(dirtyHighlights);
    });
  }

  Future<void> _pushCurriculum(RemoteApiService api) async {
    final grades = await _isar.gradeLocals.filter().isDirtyEqualTo(true).findAll();
    final subjects = await _isar.subjectLocals.filter().isDirtyEqualTo(true).findAll();
    final units = await _isar.unitLocals.filter().isDirtyEqualTo(true).findAll();
    final lessons = await _isar.lessonLocals.filter().isDirtyEqualTo(true).findAll();
    final steps = await _isar.stepLocals.filter().isDirtyEqualTo(true).findAll();
    final quizQuestions = await _isar.quizQuestionLocals.filter().isDirtyEqualTo(true).findAll();
    final exams = await _isar.examLocals.filter().isDirtyEqualTo(true).findAll();
    final examQuestions = await _isar.examQuestionLocals.filter().isDirtyEqualTo(true).findAll();
    final flashcards = await _isar.flashcardTemplateLocals.filter().isDirtyEqualTo(true).findAll();
    final textbooks = await _isar.textbookLocals.filter().isDirtyEqualTo(true).findAll();
    final worksheets = await _isar.worksheetLocals.filter().isDirtyEqualTo(true).findAll();

    if (grades.isEmpty && subjects.isEmpty && units.isEmpty && lessons.isEmpty && steps.isEmpty) return;

    await api.pushCurriculum(
      grades: grades.map((e) => {'uuid': e.uuid, 'level': e.level, 'name': e.name, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      subjects: subjects.map((e) => {'uuid': e.uuid, 'grade_uuid': e.gradeUuid, 'name': e.name, 'slug': e.slug, 'icon_url': e.iconUrl, 'color_code': e.colorCode, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      units: units.map((e) => {'uuid': e.uuid, 'subject_uuid': e.subjectUuid, 'sequence_number': e.sequenceNumber, 'title': e.title, 'description': e.description, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      lessons: lessons.map((e) => {'uuid': e.uuid, 'unit_uuid': e.unitUuid, 'sequence_number': e.sequenceNumber, 'title': e.title, 'estimated_minutes': e.estimatedMinutes, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      steps: steps.map((e) => {
        'uuid': e.uuid,
        'lesson_uuid': e.lessonUuid,
        'sequence_number': e.sequenceNumber,
        'title': e.title,
        'type': e.type.name,
        'content_markdown': e.contentMarkdown,
        'youtube_video_id': e.youtubeVideoId,
        'updated_at': e.updatedAt.toIso8601String(),
        'is_deleted': e.isDeleted,
      }).toList(),
      quizQuestions: quizQuestions.map((e) => {'uuid': e.uuid, 'step_uuid': e.stepUuid, 'question_text': e.questionText, 'options': e.options, 'correct_option_index': e.correctOptionIndex, 'explanation': e.explanation, 'points': e.points, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      exams: exams.map((e) => {'uuid': e.uuid, 'subject_uuid': e.subjectUuid, 'title': e.title, 'description': e.description, 'duration_minutes': e.durationMinutes, 'is_published': e.isPublished, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      examQuestions: examQuestions.map((e) => {'uuid': e.uuid, 'exam_uuid': e.examUuid, 'question_text': e.questionText, 'options': e.options, 'correct_option_index': e.correctOptionIndex, 'explanation': e.explanation, 'points': e.points, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      flashcards: flashcards.map((e) => {'uuid': e.uuid, 'unit_uuid': e.unitUuid, 'front_text': e.frontText, 'back_text': e.backText, 'image_url': e.imageUrl, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      textbooks: textbooks.map((e) => {'uuid': e.uuid, 'subject_uuid': e.subjectUuid, 'title': e.title, 'pdf_url': e.pdfUrl, 'total_pages': e.totalPages, 'is_published': e.isPublished, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
      worksheets: worksheets.map((e) => {'uuid': e.uuid, 'unit_uuid': e.unitUuid, 'title': e.title, 'pdf_url': e.pdfUrl, 'updated_at': e.updatedAt.toIso8601String(), 'is_deleted': e.isDeleted}).toList(),
    );

    await _isar.writeTxn(() async {
      for (var g in grades) {
        g.isDirty = false;
      }
      await _isar.gradeLocals.putAll(grades);
      for (var s in subjects) {
        s.isDirty = false;
      }
      await _isar.subjectLocals.putAll(subjects);
      for (var u in units) {
        u.isDirty = false;
      }
      await _isar.unitLocals.putAll(units);
      for (var l in lessons) {
        l.isDirty = false;
      }
      await _isar.lessonLocals.putAll(lessons);
      for (var st in steps) {
        st.isDirty = false;
      }
      await _isar.stepLocals.putAll(steps);
      for (var q in quizQuestions) {
        q.isDirty = false;
      }
      await _isar.quizQuestionLocals.putAll(quizQuestions);
      for (var ex in exams) {
        ex.isDirty = false;
      }
      await _isar.examLocals.putAll(exams);
      for (var eq in examQuestions) {
        eq.isDirty = false;
      }
      await _isar.examQuestionLocals.putAll(examQuestions);
      for (var f in flashcards) {
        f.isDirty = false;
      }
      await _isar.flashcardTemplateLocals.putAll(flashcards);
      for (var t in textbooks) {
        t.isDirty = false;
      }
      await _isar.textbookLocals.putAll(textbooks);
      for (var w in worksheets) {
        w.isDirty = false;
      }
      await _isar.worksheetLocals.putAll(worksheets);
    });
  }

  Future<void> _pullCurriculum(Map<String, dynamic> curriculum) async {
    await _isar.writeTxn(() async {
      // Grades
      final grades = curriculum['grades'] as List<dynamic>?;
      if (grades != null) {
        for (final g in grades) {
          final uuid = g['id']?.toString() ?? g['uuid']?.toString();
          if (uuid == null) continue;
          final existing = await _isar.gradeLocals.filter().uuidEqualTo(uuid).findFirst();
          final grade = existing ?? GradeLocal()..uuid = uuid;
          grade.level = (g['level'] ?? 0) as int;
          grade.nameJson = jsonEncode(g['name'] ?? {});
          grade.updatedAt = DateTime.now();
          grade.isDirty = false;
          await _isar.gradeLocals.put(grade);
        }
      }

      // Subjects
      final subjects = curriculum['subjects'] as List<dynamic>?;
      if (subjects != null) {
        for (final s in subjects) {
          final uuid = s['id']?.toString() ?? s['uuid']?.toString();
          final gradeUuid = s['grade_id']?.toString() ?? s['gradeUuid']?.toString();
          if (uuid == null || gradeUuid == null) continue;
          final existing = await _isar.subjectLocals.filter().uuidEqualTo(uuid).findFirst();
          final subject = existing ?? SubjectLocal()..uuid = uuid;
          subject.gradeUuid = gradeUuid;
          subject.slug = s['slug']?.toString() ?? '';
          subject.iconUrl = s['icon_url']?.toString();
          subject.colorCode = s['color_code']?.toString();
          subject.nameJson = jsonEncode(s['name'] ?? {});
          subject.updatedAt = DateTime.now();
          subject.isDirty = false;
          await _isar.subjectLocals.put(subject);
        }
      }

      // Units
      final units = curriculum['units'] as List<dynamic>?;
      if (units != null) {
        for (final u in units) {
          final uuid = u['id']?.toString() ?? u['uuid']?.toString();
          final subjectUuid = u['subject_id']?.toString() ?? u['subjectUuid']?.toString();
          if (uuid == null || subjectUuid == null) continue;
          final existing = await _isar.unitLocals.filter().uuidEqualTo(uuid).findFirst();
          final unit = existing ?? UnitLocal()..uuid = uuid;
          unit.subjectUuid = subjectUuid;
          unit.sequenceNumber = (u['sequence_number'] ?? 0) as int;
          unit.titleJson = jsonEncode(u['title'] ?? {});
          unit.descriptionJson = jsonEncode(u['description'] ?? {});
          unit.textbookPdfUrlJson = jsonEncode(u['textbook_pdf_url'] ?? {});
          unit.textbookPdfSizeJson = jsonEncode(u['textbook_pdf_size'] ?? {});
          unit.updatedAt = DateTime.now();
          unit.isDirty = false;
          await _isar.unitLocals.put(unit);
        }
      }

      // Lessons
      final lessons = curriculum['lessons'] as List<dynamic>?;
      if (lessons != null) {
        for (final l in lessons) {
          final uuid = l['id']?.toString() ?? l['uuid']?.toString();
          final unitUuid = l['unit_id']?.toString() ?? l['unitUuid']?.toString();
          if (uuid == null || unitUuid == null) continue;
          final existing = await _isar.lessonLocals.filter().uuidEqualTo(uuid).findFirst();
          final lesson = existing ?? LessonLocal()..uuid = uuid;
          lesson.unitUuid = unitUuid;
          lesson.sequenceNumber = (l['sequence_number'] ?? 0) as int;
          lesson.titleJson = jsonEncode(l['title'] ?? {});
          lesson.estimatedMinutes = (l['estimated_minutes'] ?? 0) as int;
          lesson.updatedAt = DateTime.now();
          lesson.isDirty = false;
          await _isar.lessonLocals.put(lesson);
        }
      }

      // Steps
      final steps = curriculum['steps'] as List<dynamic>?;
      if (steps != null) {
        for (final s in steps) {
          final uuid = s['id']?.toString() ?? s['uuid']?.toString();
          final lessonUuid = s['lesson_id']?.toString() ?? s['lessonUuid']?.toString();
          if (uuid == null || lessonUuid == null) continue;
          final existing = await _isar.stepLocals.filter().uuidEqualTo(uuid).findFirst();
          final step = existing ?? StepLocal()..uuid = uuid;
          step.lessonUuid = lessonUuid;
          step.sequenceNumber = (s['sequence_number'] ?? 0) as int;
          step.titleJson = jsonEncode(s['title'] ?? {});
          step.contentMarkdownJson = jsonEncode(s['content_markdown'] ?? {});
          step.youtubeVideoId = s['youtube_video_id']?.toString();
          final typeStr = s['type']?.toString() ?? 'read';
          step.type = typeStr == 'quiz'
              ? StepType.quiz
              : typeStr == 'flashcardReview'
                  ? StepType.flashcardReview
                  : StepType.read;
          step.updatedAt = DateTime.now();
          step.isDirty = false;
          await _isar.stepLocals.put(step);
        }
      }

      // Quiz Questions
      final quizQuestions = curriculum['quiz_questions'] as List<dynamic>?;
      if (quizQuestions != null) {
        for (final q in quizQuestions) {
          final uuid = q['id']?.toString() ?? q['uuid']?.toString();
          final stepUuid = q['step_id']?.toString() ?? q['stepUuid']?.toString();
          if (uuid == null || stepUuid == null) continue;
          final existing = await _isar.quizQuestionLocals.filter().uuidEqualTo(uuid).findFirst();
          final question = existing ?? QuizQuestionLocal()..uuid = uuid;
          question.stepUuid = stepUuid;
          question.questionTextJson = jsonEncode(q['question_text'] ?? {});
          question.optionsJson = jsonEncode(q['options'] ?? []);
          question.correctOptionIndex = (q['correct_option_index'] ?? 0) as int;
          question.explanationJson = jsonEncode(q['explanation'] ?? {});
          question.points = (q['points'] ?? 1) as int;
          question.updatedAt = DateTime.now();
          question.isDirty = false;
          await _isar.quizQuestionLocals.put(question);
        }
      }

      // Exams
      final exams = curriculum['exams'] as List<dynamic>?;
      if (exams != null) {
        for (final e in exams) {
          final uuid = e['id']?.toString() ?? e['uuid']?.toString();
          final subjectUuid = e['subject_id']?.toString() ?? e['subjectUuid']?.toString();
          if (uuid == null || subjectUuid == null) continue;
          final existing = await _isar.examLocals.filter().uuidEqualTo(uuid).findFirst();
          final exam = existing ?? ExamLocal()..uuid = uuid;
          exam.subjectUuid = subjectUuid;
          exam.titleJson = jsonEncode(e['title'] ?? {});
          exam.descriptionJson = jsonEncode(e['description'] ?? {});
          exam.durationMinutes = (e['duration_minutes'] ?? 60) as int;
          exam.updatedAt = DateTime.now();
          exam.isDirty = false;
          await _isar.examLocals.put(exam);
        }
      }

      // Exam Questions
      final examQuestions = curriculum['exam_questions'] as List<dynamic>?;
      if (examQuestions != null) {
        for (final eq in examQuestions) {
          final uuid = eq['id']?.toString() ?? eq['uuid']?.toString();
          final examUuid = eq['exam_id']?.toString() ?? eq['examUuid']?.toString();
          if (uuid == null || examUuid == null) continue;
          final existing = await _isar.examQuestionLocals.filter().uuidEqualTo(uuid).findFirst();
          final question = existing ?? ExamQuestionLocal()..uuid = uuid;
          question.examUuid = examUuid;
          question.questionTextJson = jsonEncode(eq['question_text'] ?? {});
          question.optionsJson = jsonEncode(eq['options'] ?? []);
          question.correctOptionIndex = (eq['correct_option_index'] ?? 0) as int;
          question.explanationJson = jsonEncode(eq['explanation'] ?? {});
          question.points = (eq['points'] ?? 1) as int;
          question.updatedAt = DateTime.now();
          question.isDirty = false;
          await _isar.examQuestionLocals.put(question);
        }
      }

      // Flashcard Templates
      final flashcards = curriculum['flashcard_templates'] as List<dynamic>?;
      if (flashcards != null) {
        for (final f in flashcards) {
          final uuid = f['id']?.toString() ?? f['uuid']?.toString();
          final unitUuid = f['unit_id']?.toString() ?? f['unitUuid']?.toString();
          if (uuid == null || unitUuid == null) continue;
          final existing = await _isar.flashcardTemplateLocals.filter().uuidEqualTo(uuid).findFirst();
          final card = existing ?? FlashcardTemplateLocal()..uuid = uuid;
          card.unitUuid = unitUuid;
          card.frontTextJson = jsonEncode(f['front_text'] ?? {});
          card.backTextJson = jsonEncode(f['back_text'] ?? {});
          card.imageUrl = f['image_url']?.toString();
          card.updatedAt = DateTime.now();
          card.isDirty = false;
          await _isar.flashcardTemplateLocals.put(card);
        }
      }

      // Textbooks
      final textbooks = curriculum['textbooks'] as List<dynamic>?;
      if (textbooks != null) {
        for (final t in textbooks) {
          final uuid = t['id']?.toString() ?? t['uuid']?.toString();
          final subjectUuid = t['subject_id']?.toString() ?? t['subjectUuid']?.toString();
          if (uuid == null || subjectUuid == null) continue;
          final existing = await _isar.textbookLocals.filter().uuidEqualTo(uuid).findFirst();
          final textbook = existing ?? TextbookLocal()..uuid = uuid;
          textbook.subjectUuid = subjectUuid;
          textbook.titleJson = jsonEncode(t['title'] ?? {});
          textbook.pdfUrl = t['pdf_url']?.toString() ?? '';
          textbook.pdfSizeBytes = (t['pdf_size_bytes'] ?? 0) as int?;
          textbook.coverImageUrl = t['cover_image_url']?.toString();
          textbook.totalPages = (t['total_pages'] ?? 0) as int?;
          textbook.isPublished = (t['is_published'] ?? true) as bool;
          textbook.updatedAt = DateTime.now();
          textbook.isDirty = false;
          await _isar.textbookLocals.put(textbook);
        }
      }

      // Worksheets
      final worksheets = curriculum['worksheets'] as List<dynamic>?;
      if (worksheets != null) {
        for (final w in worksheets) {
          final uuid = w['id']?.toString() ?? w['uuid']?.toString();
          final unitUuid = w['unit_id']?.toString() ?? w['unitUuid']?.toString();
          if (uuid == null || unitUuid == null) continue;
          final existing = await _isar.worksheetLocals.filter().uuidEqualTo(uuid).findFirst();
          final ws = existing ?? WorksheetLocal()..uuid = uuid;
          ws.unitUuid = unitUuid;
          ws.titleJson = jsonEncode(w['title'] ?? {});
          ws.pdfUrlJson = jsonEncode(w['pdf_url'] ?? {});
          ws.pdfSizeJson = jsonEncode(w['pdf_size'] ?? {});
          ws.updatedAt = DateTime.now();
          ws.isDirty = false;
          await _isar.worksheetLocals.put(ws);
        }
      }
    });
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final isar = ref.watch(isarProvider);
  return SyncNotifier(isar, ref);
});
