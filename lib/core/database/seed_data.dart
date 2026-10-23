import 'package:isar_community/isar.dart';
import 'isar_models.dart';

class SeedData {
  static Future<void> seed(Isar isar) async {
    // Check if Grade 5 curriculum & textbooks are already seeded
    final grade5Exists = await isar.gradeLocals.filter().levelEqualTo(5).findFirst() != null;
    final grade5MathTextbook = await isar.textbookLocals.filter().uuidEqualTo('textbook-5-math-uuid').findFirst() != null;
    
    if (grade5Exists && grade5MathTextbook) return;

    await isar.writeTxn(() async {
      // 1. Seed All Grades (Grades 1 to 12)
      final allGradeLevels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
      for (final level in allGradeLevels) {
        final existingGrade = await isar.gradeLocals.filter().levelEqualTo(level).findFirst();
        final grade = existingGrade ?? GradeLocal()
          ..uuid = 'grade-$level-uuid'
          ..level = level
          ..name = {'en': 'Grade $level', 'am': 'ክፍል $level'}
          ..updatedAt = DateTime.now();
        await isar.gradeLocals.put(grade);

        // For non-Grade-5 grades, seed default Mathematics subject if missing
        if (level != 5) {
          final existingSub = await isar.subjectLocals.filter().uuidEqualTo('math-$level-uuid').findFirst();
          if (existingSub == null) {
            final math = SubjectLocal()
              ..uuid = 'math-$level-uuid'
              ..gradeUuid = grade.uuid
              ..name = {'en': 'Mathematics', 'am': 'ሒሳብ'}
              ..slug = 'math'
              ..colorCode = '#1E88E5'
              ..updatedAt = DateTime.now();
            await isar.subjectLocals.put(math);

            final textbook = TextbookLocal()
              ..uuid = 'textbook-$level-uuid'
              ..subjectUuid = math.uuid
              ..title = {'en': 'Grade $level Mathematics Textbook', 'am': 'የክፍል $level ሒሳብ መማሪያ መጽሐፍ'}
              ..pdfUrl = 'https://dwstnslgivrkqrfuovtn.supabase.co/storage/v1/object/public/content/sample.pdf'
              ..pdfSizeBytes = 5000000
              ..isPublished = true
              ..updatedAt = DateTime.now();
            await isar.textbookLocals.put(textbook);
          }
        }
      }

      // 2. Seed Official Grade 5 Subjects and Bundled Textbooks
      const grade5Uuid = 'grade-5-uuid';

      // 2.1 Grade 5 Mathematics
      final math5 = SubjectLocal()
        ..uuid = 'math-5-uuid'
        ..gradeUuid = grade5Uuid
        ..name = {'en': 'Mathematics', 'am': 'ሒሳብ'}
        ..slug = 'math'
        ..colorCode = '#1E88E5'
        ..updatedAt = DateTime.now();
      await isar.subjectLocals.put(math5);

      final math5Textbook = TextbookLocal()
        ..uuid = 'textbook-5-math-uuid'
        ..subjectUuid = math5.uuid
        ..title = {'en': 'Grade 5 Mathematics Student Textbook', 'am': 'የ5ኛ ክፍል ሒሳብ የተማሪ መጽሐፍ'}
        ..pdfUrl = 'assets/textbooks/grade_5/grade_5_mathematics.pdf'
        ..localPdfPath = 'assets/textbooks/grade_5/grade_5_mathematics.pdf'
        ..pdfSizeBytes = 105031573
        ..totalPages = 196
        ..isDownloaded = true
        ..isPublished = true
        ..updatedAt = DateTime.now();
      await isar.textbookLocals.put(math5Textbook);

      // Grade 5 Math Structured Learning: Unit 1
      final math5Unit1 = UnitLocal()
        ..uuid = 'unit-5-math-1-uuid'
        ..subjectUuid = math5.uuid
        ..sequenceNumber = 1
        ..title = {'en': 'Unit 1: Whole Numbers & Operations', 'am': 'ምዕራፍ 1: ሙሉ ቁጥሮች እና ስሌቶች'}
        ..description = {'en': 'Place values, addition, subtraction, multiplication and division of large numbers', 'am': 'የቁጥሮች የቤት ዋጋ፣ መደመር፣ መቀነስ፣ ማባዛት እና ማካፈል'}
        ..textbookPdfUrl = {'en': 'assets/textbooks/grade_5/grade_5_mathematics.pdf'}
        ..textbookPdfSize = {'en': 105031573}
        ..updatedAt = DateTime.now();
      await isar.unitLocals.put(math5Unit1);

      final math5Lesson1 = LessonLocal()
        ..uuid = 'lesson-5-math-1-uuid'
        ..unitUuid = math5Unit1.uuid
        ..sequenceNumber = 1
        ..title = {'en': 'Place Values up to 1,000,000', 'am': 'የቁጥሮች የቤት ዋጋ እስከ 1,000,000'}
        ..estimatedMinutes = 20
        ..updatedAt = DateTime.now();
      await isar.lessonLocals.put(math5Lesson1);

      final math5Step1 = StepLocal()
        ..uuid = 'step-5-math-1-uuid'
        ..lessonUuid = math5Lesson1.uuid
        ..sequenceNumber = 1
        ..title = {'en': 'Reading and Writing Numbers', 'am': 'ቁጥሮችን ማንበብና መጻፍ'}
        ..type = StepType.read
        ..contentMarkdown = {
          'en': '# Whole Numbers up to 1,000,000\nIn Grade 5, you learn to read, write, compare, and order numbers up to 1,000,000. \n\n### Place Value Chart\n* Ones, Tens, Hundreds\n* Thousands, Ten Thousands, Hundred Thousands\n* Millions',
          'am': '# ሙሉ ቁጥሮች እስከ 1,000,000\nበ5ኛ ክፍል ቁጥሮችን እስከ 1,000,000 ማንበብ፣ መጻፍ፣ ማወዳደር እና በቅደም ተከተል ማስቀመጥን ይማራሉ።\n\n### የቤት ዋጋ ሰንጠረዥ\n* አንድ ቤት፣ አስር ቤት፣ መቶ ቤት\n* ሺህ ቤት፣ አስር ሺህ ቤት፣ መቶ ሺህ ቤት\n* ሚሊዮን ቤት'
        }
        ..updatedAt = DateTime.now();
      await isar.stepLocals.put(math5Step1);

      // 2.2 Grade 5 English
      final english5 = SubjectLocal()
        ..uuid = 'english-5-uuid'
        ..gradeUuid = grade5Uuid
        ..name = {'en': 'English', 'am': 'እንግሊዝኛ'}
        ..slug = 'english'
        ..colorCode = '#2E7D32'
        ..updatedAt = DateTime.now();
      await isar.subjectLocals.put(english5);

      final english5Textbook = TextbookLocal()
        ..uuid = 'textbook-5-english-uuid'
        ..subjectUuid = english5.uuid
        ..title = {'en': 'English for Ethiopia Grade 5 Student Textbook', 'am': 'የ5ኛ ክፍል እንግሊዝኛ የተማሪ መጽሐፍ'}
        ..pdfUrl = 'assets/textbooks/grade_5/grade_5_english.pdf'
        ..localPdfPath = 'assets/textbooks/grade_5/grade_5_english.pdf'
        ..pdfSizeBytes = 33750748
        ..totalPages = 168
        ..isDownloaded = true
        ..isPublished = true
        ..updatedAt = DateTime.now();
      await isar.textbookLocals.put(english5Textbook);

      final english5Unit1 = UnitLocal()
        ..uuid = 'unit-5-eng-1-uuid'
        ..subjectUuid = english5.uuid
        ..sequenceNumber = 1
        ..title = {'en': 'Unit 1: Holiday Activities', 'am': 'ምዕራፍ 1: የበዓላት እንቅስቃሴዎች'}
        ..description = {'en': 'Talking about past holidays, traditions, and celebrations', 'am': 'ስለ በዓላት፣ ባህሎችና አከባበሮች መናገር'}
        ..textbookPdfUrl = {'en': 'assets/textbooks/grade_5/grade_5_english.pdf'}
        ..textbookPdfSize = {'en': 33750748}
        ..updatedAt = DateTime.now();
      await isar.unitLocals.put(english5Unit1);

      final english5Lesson1 = LessonLocal()
        ..uuid = 'lesson-5-eng-1-uuid'
        ..unitUuid = english5Unit1.uuid
        ..sequenceNumber = 1
        ..title = {'en': 'Talking About Holidays', 'am': 'ስለ በዓላት መወያየት'}
        ..estimatedMinutes = 15
        ..updatedAt = DateTime.now();
      await isar.lessonLocals.put(english5Lesson1);

      final english5Step1 = StepLocal()
        ..uuid = 'step-5-eng-1-uuid'
        ..lessonUuid = english5Lesson1.uuid
        ..sequenceNumber = 1
        ..title = {'en': 'Holiday Vocabulary & Reading', 'am': 'የበዓላት ቃላትና ንባብ'}
        ..type = StepType.read
        ..contentMarkdown = {
          'en': '# Holiday Activities\nLearn essential vocabulary related to holidays and celebrations in Ethiopia.\n\n* Festival\n* Celebrate\n* Traditional food\n* Family gathering',
          'am': '# የበዓላት እንቅስቃሴዎች\nበኢትዮጵያ ውስጥ ከበዓላትና ዝግጅቶች ጋር የተያያዙ ቁልፍ ቃላትን ይማሩ።\n\n* በዓል\n* ማክበር\n* ባህላዊ ምግብ\n* የቤተሰብ መሰብሰብ'
        }
        ..updatedAt = DateTime.now();
      await isar.stepLocals.put(english5Step1);

      // 2.3 Grade 5 Amharic
      final amharic5 = SubjectLocal()
        ..uuid = 'amharic-5-uuid'
        ..gradeUuid = grade5Uuid
        ..name = {'en': 'Amharic', 'am': 'አማርኛ'}
        ..slug = 'amharic'
        ..colorCode = '#E65100'
        ..updatedAt = DateTime.now();
      await isar.subjectLocals.put(amharic5);

      final amharic5Textbook = TextbookLocal()
        ..uuid = 'textbook-5-amharic-uuid'
        ..subjectUuid = amharic5.uuid
        ..title = {'en': 'Grade 5 Amharic Student Textbook', 'am': 'የ5ኛ ክፍል አማርኛ የተማሪ መጽሐፍ'}
        ..pdfUrl = 'assets/textbooks/grade_5/grade_5_amharic.pdf'
        ..localPdfPath = 'assets/textbooks/grade_5/grade_5_amharic.pdf'
        ..pdfSizeBytes = 4371111
        ..totalPages = 152
        ..isDownloaded = true
        ..isPublished = true
        ..updatedAt = DateTime.now();
      await isar.textbookLocals.put(amharic5Textbook);

      // 2.4 Grade 5 Environmental Science
      final env5 = SubjectLocal()
        ..uuid = 'env-5-uuid'
        ..gradeUuid = grade5Uuid
        ..name = {'en': 'Environmental Science', 'am': 'የአካባቢ ሳይንስ'}
        ..slug = 'environmental-science'
        ..colorCode = '#00695C'
        ..updatedAt = DateTime.now();
      await isar.subjectLocals.put(env5);

      final env5Textbook = TextbookLocal()
        ..uuid = 'textbook-5-env-uuid'
        ..subjectUuid = env5.uuid
        ..title = {'en': 'Grade 5 Environmental Science Student Textbook', 'am': 'የ5ኛ ክፍል የአካባቢ ሳይንስ የተማሪ መጽሐፍ'}
        ..pdfUrl = 'assets/textbooks/grade_5/grade_5_environmental_science.pdf'
        ..localPdfPath = 'assets/textbooks/grade_5/grade_5_environmental_science.pdf'
        ..pdfSizeBytes = 28098175
        ..totalPages = 180
        ..isDownloaded = true
        ..isPublished = true
        ..updatedAt = DateTime.now();
      await isar.textbookLocals.put(env5Textbook);

      // 2.5 Grade 5 Performing and Visual Arts
      final pva5 = SubjectLocal()
        ..uuid = 'pva-5-uuid'
        ..gradeUuid = grade5Uuid
        ..name = {'en': 'Performing & Visual Arts', 'am': 'የክወናና የዕይታ ጥበባት'}
        ..slug = 'pva'
        ..colorCode = '#6A1B9A'
        ..updatedAt = DateTime.now();
      await isar.subjectLocals.put(pva5);

      final pva5Textbook = TextbookLocal()
        ..uuid = 'textbook-5-pva-uuid'
        ..subjectUuid = pva5.uuid
        ..title = {'en': 'Grade 5 Performing & Visual Arts Student Textbook', 'am': 'የ5ኛ ክፍል የክወናና የዕይታ ጥበባት የተማሪ መጽሐፍ'}
        ..pdfUrl = 'assets/textbooks/grade_5/grade_5_pva.pdf'
        ..localPdfPath = 'assets/textbooks/grade_5/grade_5_pva.pdf'
        ..pdfSizeBytes = 81697973
        ..totalPages = 144
        ..isDownloaded = true
        ..isPublished = true
        ..updatedAt = DateTime.now();
      await isar.textbookLocals.put(pva5Textbook);

      // 3. Keep original unit/lesson/step for Grade 9 Math specifically for legacy tests
      final grade9math = await isar.subjectLocals.filter().uuidEqualTo('math-9-uuid').findFirst();
      if (grade9math != null) {
        final existingUnit1 = await isar.unitLocals.filter().uuidEqualTo('unit-1-uuid').findFirst();
        if (existingUnit1 == null) {
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
      }
    });
  }
}
