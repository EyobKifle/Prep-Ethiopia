import 'package:isar_community/isar.dart';
import 'isar_models.dart';

class SeedData {
  static Future<void> seed(Isar isar) async {
    // Check if basic curriculum data exists for new overhaul
    final grade7Exists = await isar.gradeLocals.filter().levelEqualTo(7).findFirst() != null;
    
    if (grade7Exists) return;

    await isar.writeTxn(() async {
      // Clear existing data to ensure consistency if partially seeded
      await isar.gradeLocals.clear();
      await isar.subjectLocals.clear();
      await isar.unitLocals.clear();
      await isar.lessonLocals.clear();
      await isar.stepLocals.clear();
      await isar.textbookLocals.clear();

      final grades = [7, 8, 9, 10, 11, 12];
      for (final level in grades) {
        final grade = GradeLocal()
          ..uuid = 'grade-$level-uuid'
          ..level = level
          ..name = {'en': 'Grade $level', 'am': 'ክፍል $level'}
          ..updatedAt = DateTime.now();
        await isar.gradeLocals.put(grade);

        // Seed a default subject (Mathematics) for each grade
        final math = SubjectLocal()
          ..uuid = 'math-$level-uuid'
          ..gradeUuid = grade.uuid
          ..name = {'en': 'Mathematics', 'am': 'ሒሳብ'}
          ..slug = 'math'
          ..updatedAt = DateTime.now();
        await isar.subjectLocals.put(math);

        // Seed a textbook for each grade
        final textbook = TextbookLocal()
          ..uuid = 'textbook-$level-uuid'
          ..subjectUuid = math.uuid
          ..title = {'en': 'Grade $level Mathematics Textbook', 'am': 'የክፍል $level ሂሳብ መማሪያ መጽሐፍ'}
          ..pdfUrl = 'https://dwstnslgivrkqrfuovtn.supabase.co/storage/v1/object/public/content/sample.pdf'
          ..pdfSizeBytes = 5000000
          ..isPublished = true
          ..updatedAt = DateTime.now();
        await isar.textbookLocals.put(textbook);
      }

      // Keep original unit/lesson/step for Grade 9 Math specifically for legacy tests
      final grade9math = await isar.subjectLocals.filter().uuidEqualTo('math-9-uuid').findFirst();
      if (grade9math != null) {
        final unit1 = UnitLocal()
          ..uuid = 'unit-1-uuid'
          ..subjectUuid = grade9math.uuid
          ..sequenceNumber = 1
          ..title = {'en': 'The Number System', 'am': 'የቁጥር ሥርዓት'}
          ..description = {'en': 'Rational and Irrational numbers', 'am': 'አምክንዮአዊ እና ኢ-አምክንዮአዊ ቁጥሮች'}
          ..textbookPdfUrl = {'en': 'https://dwstnslgivrkqrfuovtn.supabase.co/storage/v1/object/public/content/sample.pdf'}
          ..textbookPdfSize = {'en': 5000000}
          ..updatedAt = DateTime.now();
        await isar.unitLocals.put(unit1);

        final lesson1 = LessonLocal()
          ..uuid = 'lesson-1-uuid'
          ..unitUuid = unit1.uuid
          ..sequenceNumber = 1
          ..title = {'en': 'Introduction to Real Numbers', 'am': 'ወደ እውነተኛ ቁጥሮች መግቢያ'}
          ..estimatedMinutes = 15
          ..updatedAt = DateTime.now();
        await isar.lessonLocals.put(lesson1);

        final step1 = StepLocal()
          ..uuid = 'step-1-uuid'
          ..lessonUuid = lesson1.uuid
          ..sequenceNumber = 1
          ..title = {'en': 'Definitions', 'am': 'ትርጓሜዎች'}
          ..type = StepType.read
          ..contentMarkdown = {'en': '# Real Numbers\nDefinition of real numbers...', 'am': '# እውነተኛ ቁጥሮች\nየእውነተኛ ቁጥሮች ትርጓሜ...'}
          ..updatedAt = DateTime.now();
        await isar.stepLocals.put(step1);
      }
    });
  }
}
