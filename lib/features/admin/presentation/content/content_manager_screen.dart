import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../sync/sync_service.dart';

class ContentManagerScreen extends ConsumerStatefulWidget {
  const ContentManagerScreen({super.key});

  @override
  ConsumerState<ContentManagerScreen> createState() => _ContentManagerScreenState();
}

class _ContentManagerScreenState extends ConsumerState<ContentManagerScreen> {
  bool _isLoading = true;
  List<GradeLocal> _grades = [];
  Map<String, List<SubjectLocal>> _gradeSubjectsMap = {};
  Map<String, List<UnitLocal>> _subjectUnitsMap = {};
  Map<String, List<ExamLocal>> _subjectExamsMap = {};
  Map<String, List<LessonLocal>> _unitLessonsMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllContent();
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);

    final grades = await isar.gradeLocals.filter().isDeletedEqualTo(false).sortByLevel().findAll();
    final subjects = await isar.subjectLocals.filter().isDeletedEqualTo(false).findAll();
    final units = await isar.unitLocals.filter().isDeletedEqualTo(false).sortBySequenceNumber().findAll();
    final lessons = await isar.lessonLocals.filter().isDeletedEqualTo(false).sortBySequenceNumber().findAll();
    final exams = await isar.examLocals.filter().isDeletedEqualTo(false).findAll();

    final gMap = <String, List<SubjectLocal>>{};
    for (var s in subjects) {
      gMap.putIfAbsent(s.gradeUuid, () => []).add(s);
    }

    final sMap = <String, List<UnitLocal>>{};
    for (var u in units) {
      sMap.putIfAbsent(u.subjectUuid, () => []).add(u);
    }

    final eMap = <String, List<ExamLocal>>{};
    for (var e in exams) {
      eMap.putIfAbsent(e.subjectUuid, () => []).add(e);
    }

    final uMap = <String, List<LessonLocal>>{};
    for (var l in lessons) {
      uMap.putIfAbsent(l.unitUuid, () => []).add(l);
    }

    if (mounted) {
      setState(() {
        _grades = grades;
        _gradeSubjectsMap = gMap;
        _subjectUnitsMap = sMap;
        _subjectExamsMap = eMap;
        _unitLessonsMap = uMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('contentManager')),
        actions: [
          if (syncState.pendingItemsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                label: Text('${syncState.pendingItemsCount} pending'),
                backgroundColor: Colors.orange.shade100,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncProvider.notifier).triggerSync(),
            tooltip: 'Sync Changes',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddGradeDialog(),
            tooltip: context.tr('addGrade'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllContent,
        child: ListView.builder(
          itemCount: _grades.length,
          itemBuilder: (context, index) {
            final grade = _grades[index];
            return _buildGradeTile(grade);
          },
        ),
      ),
    );
  }

  Widget _buildGradeTile(GradeLocal grade) {
    final subjects = _gradeSubjectsMap[grade.uuid] ?? [];
    return ExpansionTile(
      title: Text('Grade ${grade.level} - ${grade.name.getLocalized(context.currentLocale)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => _showAddSubjectDialog(grade.uuid),
            tooltip: context.tr('addSubject'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => _confirmDelete('grade', grade.uuid),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: subjects.map((s) => _buildSubjectTile(s)).toList(),
    );
  }

  Widget _buildSubjectTile(SubjectLocal subject) {
    final units = _subjectUnitsMap[subject.uuid] ?? [];
    final exams = _subjectExamsMap[subject.uuid] ?? [];
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ExpansionTile(
        title: Text(subject.name.getLocalized(context.currentLocale)),
        subtitle: Text(subject.slug),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showAddUnitDialog(subject.uuid),
              tooltip: context.tr('addUnit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete('subject', subject.uuid),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          ...units.map((u) => _buildUnitTile(u)),
          if (exams.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Exams', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ...exams.map((e) => _buildExamTile(e)),
        ],
      ),
    );
  }

  Widget _buildExamTile(ExamLocal exam) {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: ListTile(
        title: Text(exam.title.getLocalized(context.currentLocale)),
        subtitle: Text('${exam.durationMinutes} mins'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: exam.isPublished,
              onChanged: (val) async {
                final isar = ref.read(isarProvider);
                await isar.writeTxn(() async {
                  exam.isPublished = val;
                  exam.updatedAt = DateTime.now();
                  exam.isDirty = true;
                  await isar.examLocals.put(exam);
                });
                _loadAllContent();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete('exam', exam.uuid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitTile(UnitLocal unit) {
    final lessons = _unitLessonsMap[unit.uuid] ?? [];
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: ExpansionTile(
        title: Text('Unit ${unit.sequenceNumber}: ${unit.title.getLocalized(context.currentLocale)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showAddLessonDialog(unit.uuid),
              tooltip: context.tr('addLesson'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete('unit', unit.uuid),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: lessons.map((l) => _buildLessonTile(l)).toList(),
      ),
    );
  }

  Widget _buildLessonTile(LessonLocal lesson) {
    return Padding(
      padding: const EdgeInsets.only(left: 48.0),
      child: ListTile(
        title: Text('${lesson.sequenceNumber}. ${lesson.title.getLocalized(context.currentLocale)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => context.push('/admin/lesson-editor/${lesson.uuid}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete('lesson', lesson.uuid),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String type, String uuid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this $type?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final isar = ref.read(isarProvider);
      await isar.writeTxn(() async {
        if (type == 'grade') {
          final item = await isar.gradeLocals.filter().uuidEqualTo(uuid).findFirst();
          if (item != null) { item.isDeleted = true; item.isDirty = true; await isar.gradeLocals.put(item); }
        } else if (type == 'subject') {
          final item = await isar.subjectLocals.filter().uuidEqualTo(uuid).findFirst();
          if (item != null) { item.isDeleted = true; item.isDirty = true; await isar.subjectLocals.put(item); }
        } else if (type == 'unit') {
          final item = await isar.unitLocals.filter().uuidEqualTo(uuid).findFirst();
          if (item != null) { item.isDeleted = true; item.isDirty = true; await isar.unitLocals.put(item); }
        } else if (type == 'lesson') {
          final item = await isar.lessonLocals.filter().uuidEqualTo(uuid).findFirst();
          if (item != null) { item.isDeleted = true; item.isDirty = true; await isar.lessonLocals.put(item); }
        } else if (type == 'exam') {
          final item = await isar.examLocals.filter().uuidEqualTo(uuid).findFirst();
          if (item != null) { item.isDeleted = true; item.isDirty = true; await isar.examLocals.put(item); }
        }
      });
      _loadAllContent();
    }
  }

  // --- Dialogs for Adding Content ---

  void _showAddGradeDialog() {
    final levelController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('addGrade')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: levelController, decoration: const InputDecoration(labelText: 'Level (e.g. 7)')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name (e.g. Grade 7)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final level = int.tryParse(levelController.text) ?? 0;
              final isar = ref.read(isarProvider);
              final grade = GradeLocal()
                ..uuid = 'grade_$level'
                ..level = level
                ..name = {'en': nameController.text, 'am': nameController.text}
                ..updatedAt = DateTime.now()
                ..isDirty = true;
              await isar.writeTxn(() => isar.gradeLocals.put(grade));
              if (context.mounted) {
                Navigator.pop(context);
                _loadAllContent();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(String gradeUuid) {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('addSubject')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Subject Name')),
            TextField(controller: slugController, decoration: const InputDecoration(labelText: 'Slug (e.g. biology-g7)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final isar = ref.read(isarProvider);
              final subject = SubjectLocal()
                ..uuid = 'sub_${DateTime.now().millisecondsSinceEpoch}'
                ..gradeUuid = gradeUuid
                ..name = {'en': nameController.text, 'am': nameController.text}
                ..slug = slugController.text
                ..updatedAt = DateTime.now()
                ..isDirty = true;
              await isar.writeTxn(() => isar.subjectLocals.put(subject));
              if (context.mounted) {
                Navigator.pop(context);
                _loadAllContent();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddUnitDialog(String subjectUuid) {
    final titleController = TextEditingController();
    final seqController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('addUnit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: seqController, decoration: const InputDecoration(labelText: 'Unit Number')),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Unit Title')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final isar = ref.read(isarProvider);
              final unit = UnitLocal()
                ..uuid = 'unit_${DateTime.now().millisecondsSinceEpoch}'
                ..subjectUuid = subjectUuid
                ..sequenceNumber = int.tryParse(seqController.text) ?? 1
                ..title = {'en': titleController.text, 'am': titleController.text}
                ..description = {'en': '', 'am': ''}
                ..textbookPdfUrl = {}
                ..textbookPdfSize = {}
                ..updatedAt = DateTime.now()
                ..isDirty = true;
              await isar.writeTxn(() => isar.unitLocals.put(unit));
              if (context.mounted) {
                Navigator.pop(context);
                _loadAllContent();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddLessonDialog(String unitUuid) {
    final titleController = TextEditingController();
    final seqController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('addLesson')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: seqController, decoration: const InputDecoration(labelText: 'Lesson Number')),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Lesson Title')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final isar = ref.read(isarProvider);
              final lesson = LessonLocal()
                ..uuid = 'lesson_${DateTime.now().millisecondsSinceEpoch}'
                ..unitUuid = unitUuid
                ..sequenceNumber = int.tryParse(seqController.text) ?? 1
                ..title = {'en': titleController.text, 'am': titleController.text}
                ..estimatedMinutes = 15
                ..updatedAt = DateTime.now()
                ..isDirty = true;
              await isar.writeTxn(() => isar.lessonLocals.put(lesson));
              if (context.mounted) {
                Navigator.pop(context);
                _loadAllContent();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
