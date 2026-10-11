import 'dart:convert';
import 'package:isar_community/isar.dart';
import '../utils/fast_hash.dart';

part 'isar_models.g.dart';

// Helper extension to retrieve localized values from translations easily offline.
// Usage: grade.name.getLocalized(localeCode)
extension LocalizedMap on Map<String, String> {
  String getLocalized(String languageCode) {
    return this[languageCode] ?? this['en'] ?? values.firstOrNull ?? '';
  }
}

// =========================================================================
// READ-ONLY SYNCED CONTENT MODELS
// =========================================================================

@collection
class GradeLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  late int level;
  
  late String nameJson;
  @ignore
  Map<String, String> get name => jsonDecode(nameJson).cast<String, String>();
  set name(Map<String, String> value) => nameJson = jsonEncode(value);

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class SubjectLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;
  
  @Index()
  late String gradeUuid;

  late String nameJson;
  @ignore
  Map<String, String> get name => jsonDecode(nameJson).cast<String, String>();
  set name(Map<String, String> value) => nameJson = jsonEncode(value);

  late String slug;
  String? iconUrl;
  String? colorCode;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class UnitLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String subjectUuid;

  late int sequenceNumber;
  
  late String titleJson;
  @ignore
  Map<String, String> get title => jsonDecode(titleJson).cast<String, String>();
  set title(Map<String, String> value) => titleJson = jsonEncode(value);

  late String descriptionJson;
  @ignore
  Map<String, String> get description => jsonDecode(descriptionJson).cast<String, String>();
  set description(Map<String, String> value) => descriptionJson = jsonEncode(value);

  late String textbookPdfUrlJson;
  @ignore
  Map<String, String> get textbookPdfUrl => jsonDecode(textbookPdfUrlJson).cast<String, String>();
  set textbookPdfUrl(Map<String, String> value) => textbookPdfUrlJson = jsonEncode(value);

  late String textbookPdfSizeJson;
  @ignore
  Map<String, int> get textbookPdfSize => jsonDecode(textbookPdfSizeJson).cast<String, int>();
  set textbookPdfSize(Map<String, int> value) => textbookPdfSizeJson = jsonEncode(value);
  
  // Local asset storage tracking (relative path on disk)
  String? localPdfPath;       
  bool isDownloaded = false;   

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class WorksheetLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String unitUuid;

  late String titleJson;
  @ignore
  Map<String, String> get title => jsonDecode(titleJson).cast<String, String>();
  set title(Map<String, String> value) => titleJson = jsonEncode(value);

  late String pdfUrlJson;
  @ignore
  Map<String, String> get pdfUrl => jsonDecode(pdfUrlJson).cast<String, String>();
  set pdfUrl(Map<String, String> value) => pdfUrlJson = jsonEncode(value);

  late String pdfSizeJson;
  @ignore
  Map<String, int> get pdfSize => jsonDecode(pdfSizeJson).cast<String, int>();
  set pdfSize(Map<String, int> value) => pdfSizeJson = jsonEncode(value);

  // Local storage properties
  String? localPdfPath;
  bool isDownloaded = false;

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class ExamLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String subjectUuid;

  late String titleJson;
  @ignore
  Map<String, String> get title => jsonDecode(titleJson).cast<String, String>();
  set title(Map<String, String> value) => titleJson = jsonEncode(value);

  late String descriptionJson;
  @ignore
  Map<String, String> get description => jsonDecode(descriptionJson).cast<String, String>();
  set description(Map<String, String> value) => descriptionJson = jsonEncode(value);

  late int durationMinutes;
  late bool isPublished;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class ExamQuestionLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String examUuid;

  late String questionTextJson;
  @ignore
  Map<String, String> get questionText => jsonDecode(questionTextJson).cast<String, String>();
  set questionText(Map<String, String> value) => questionTextJson = jsonEncode(value);
  
  late String optionsJson; 
  @ignore
  List<String> get options => jsonDecode(optionsJson).cast<String>();
  set options(List<String> value) => optionsJson = jsonEncode(value);
  
  late int correctOptionIndex;

  late String explanationJson;
  @ignore
  Map<String, String> get explanation => jsonDecode(explanationJson).cast<String, String>();
  set explanation(Map<String, String> value) => explanationJson = jsonEncode(value);

  late int points;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class LessonLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String unitUuid;

  late int sequenceNumber;

  late String titleJson;
  @ignore
  Map<String, String> get title => jsonDecode(titleJson).cast<String, String>();
  set title(Map<String, String> value) => titleJson = jsonEncode(value);

  late int estimatedMinutes;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class StepLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String lessonUuid;

  late int sequenceNumber;

  late String titleJson;
  @ignore
  Map<String, String> get title => jsonDecode(titleJson).cast<String, String>();
  set title(Map<String, String> value) => titleJson = jsonEncode(value);
  
  @enumerated
  late StepType type;

  late String contentMarkdownJson;
  @ignore
  Map<String, String> get contentMarkdown => jsonDecode(contentMarkdownJson).cast<String, String>();
  set contentMarkdown(Map<String, String> value) => contentMarkdownJson = jsonEncode(value);

  String? youtubeVideoId;

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

enum StepType { read, quiz, flashcardReview }

@collection
class QuizQuestionLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String stepUuid;

  late String questionTextJson;
  @ignore
  Map<String, String> get questionText => jsonDecode(questionTextJson).cast<String, String>();
  set questionText(Map<String, String> value) => questionTextJson = jsonEncode(value);

  late String optionsJson; 
  @ignore
  List<String> get options => jsonDecode(optionsJson).cast<String>();
  set options(List<String> value) => optionsJson = jsonEncode(value);

  late int correctOptionIndex;

  late String explanationJson;
  @ignore
  Map<String, String> get explanation => jsonDecode(explanationJson).cast<String, String>();
  set explanation(Map<String, String> value) => explanationJson = jsonEncode(value);

  late int points;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class FlashcardTemplateLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String unitUuid;

  late String frontTextJson;
  @ignore
  Map<String, String> get frontText => jsonDecode(frontTextJson).cast<String, String>();
  set frontText(Map<String, String> value) => frontTextJson = jsonEncode(value);

  late String backTextJson;
  @ignore
  Map<String, String> get backText => jsonDecode(backTextJson).cast<String, String>();
  set backText(Map<String, String> value) => backTextJson = jsonEncode(value);

  String? imageUrl;
  
  // Local caching status for flashcard media
  String? localImagePath;
  
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

// =========================================================================
// WRITE-ONLY & SYNCED USER PROGRESS MODELS
// =========================================================================

@collection
class ProfileLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  late String role;
  String? fullName;
  String? phoneNumber;
  late String preferredLanguage; // 'en', 'am', etc. Used to resolve translation rendering locally.
  int? selectedGradeLevel; // Selected grade (7-12) for onboarding curriculum filter

  @Index()
  late bool isDirty;
  late DateTime updatedAt;
}

@collection
class UserProgressLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String userUuid;

  @Index()
  late String stepUuid;

  late bool isCompleted;
  DateTime? completedAt;

  // Sync Metadata
  @Index()
  late bool isDirty;       // true if modified offline and not synced yet
  late bool isDeleted;     // Soft delete indicator
  late DateTime updatedAt; // Time of local edit (or server edit)
}

@collection
class QuizAttemptLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String userUuid;

  @Index()
  late String stepUuid;

  late int score;
  late int maxScore;
  late DateTime submittedAt;
  
  String? answersJson; // Serialized quiz answers for review

  // Sync Metadata
  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

@collection
class ExamAttemptLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String userUuid;

  @Index()
  late String examUuid;

  late int score;
  late int maxScore;
  int? durationSpentSeconds;
  late DateTime submittedAt;

  String? answersJson; // Serialized exam answers for review

  // Sync Metadata
  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

@collection
class UserFlashcardLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String cardTemplateUuid;

  // SuperMemo-2 Spaced Repetition parameters
  late double easeFactor;
  late int intervalDays;
  late int repetitions;
  
  @Index()
  late DateTime nextReviewAt;
  
  DateTime? lastReviewedAt;

  // Sync Metadata
  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

// =========================================================================
// OFFLINE CONFIGURATION & DIAGNOSTICS
// =========================================================================

@collection
class AppSettingsLocal {
  Id get id => fastHash(key);

  @Index(unique: true, replace: true)
  late String key;

  late String valueJson;
  @ignore
  Map<String, dynamic> get value => jsonDecode(valueJson).cast<String, dynamic>();
  set value(Map<String, dynamic> val) => valueJson = jsonEncode(val);

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
}

@collection
class FeatureFlagLocal {
  Id get id => fastHash(key);

  @Index(unique: true, replace: true)
  late String key;
  
  late String description;
  late bool isEnabled;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
}

@collection
class AppDiagnosticsLogLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  String? userUuid;
  late String logLevel;
  late String message;
  String? stackTrace;
  late String deviceInfoJson; // Stringified JSON
  late DateTime createdAt;

  @Index()
  late bool isUploaded;
  bool isDeleted = false;

  @Index()
  bool isDirty = false;
  late DateTime updatedAt;
}

// =========================================================================
// NEW PLATFORM MODELS
// =========================================================================

@collection
class TextbookLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String subjectUuid;

  late String titleJson;
  @ignore
  Map<String, String> get title => jsonDecode(titleJson).cast<String, String>();
  set title(Map<String, String> value) => titleJson = jsonEncode(value);

  late String pdfUrl;
  int? pdfSizeBytes;
  String? coverImageUrl;
  int? totalPages;
  late bool isPublished;
  
  // Local asset storage tracking
  String? localPdfPath;
  bool isDownloaded = false;

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class WorksheetQuestionLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String worksheetUuid;

  late int sequenceNumber;

  late String questionTextJson;
  @ignore
  Map<String, String> get questionText => jsonDecode(questionTextJson).cast<String, String>();
  set questionText(Map<String, String> value) => questionTextJson = jsonEncode(value);

  late String optionsJson; 
  @ignore
  List<String> get options => jsonDecode(optionsJson).cast<String>();
  set options(List<String> value) => optionsJson = jsonEncode(value);

  late int correctOptionIndex;

  late String explanationJson;
  @ignore
  Map<String, String> get explanation => jsonDecode(explanationJson).cast<String, String>();
  set explanation(Map<String, String> value) => explanationJson = jsonEncode(value);

  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class WorksheetAttemptLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String userUuid;

  @Index()
  late String worksheetUuid;

  late int score;
  late int maxScore;
  late String answersJson; // Serialized list of answers
  late DateTime submittedAt;

  // Sync Metadata
  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

@collection
class ParentStudentLinkLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String parentUuid;

  @Index()
  late String studentUuid;

  String? linkCode;
  late DateTime linkedAt;

  // Sync Metadata
  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

@collection
class TextbookNoteLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String textbookUuid;

  @Index()
  late String userUuid;

  late int pageNumber;
  late double dx;
  late double dy;
  
  String? content;

  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

@collection
class TextbookHighlightLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String textbookUuid;

  @Index()
  late String userUuid;

  late int pageNumber;
  late String selectedText;
  late String colorHex;
  
  // Storing rectangles/bounds to redraw the highlight
  late String boundsJson;

  @Index()
  late bool isDirty;
  late bool isDeleted;
  late DateTime updatedAt;
}

// =========================================================================
// AI TUTOR & CHAT MODELS
// =========================================================================

@collection
class AiChatLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String userUuid;

  String? subjectUuid;
  String? textbookUuid;
  String? lessonUuid;

  late String title;
  late DateTime createdAt;
  late DateTime updatedAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
}

@collection
class AiMessageLocal {
  Id get id => fastHash(uuid);

  @Index(unique: true, replace: true)
  late String uuid;

  @Index()
  late String chatUuid;

  late String role; // 'user' or 'assistant'
  late String content;
  
  // Sources used for RAG (Retrieval-Augmented Generation)
  String? sourcesJson; // Serialized list of {textbookUuid, pageNumber, snippet}

  late DateTime createdAt;

  @Index()
  bool isDirty = false;
  bool isDeleted = false;
  late DateTime updatedAt;
}
