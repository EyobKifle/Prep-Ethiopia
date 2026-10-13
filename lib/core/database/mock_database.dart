import 'package:flutter/foundation.dart' show kIsWeb;

/// Common database interface for cross-platform abstraction
abstract class DatabaseInterface {
  Future<void> close();
}

/// Mock in-memory database for web and testing environments
class MockDatabase implements DatabaseInterface {
  final Map<String, Map<dynamic, dynamic>> _collections = {};

  MockDatabase() {
    _initCollections();
  }

  void _initCollections() {
    final collections = [
      'gradeLocals',
      'subjectLocals',
      'unitLocals',
      'worksheetLocals',
      'examLocals',
      'examQuestionLocals',
      'lessonLocals',
      'stepLocals',
      'quizQuestionLocals',
      'flashcardTemplateLocals',
      'profileLocals',
      'userProgressLocals',
      'quizAttemptLocals',
      'examAttemptLocals',
      'userFlashcardLocals',
      'featureFlagLocals',
      'appDiagnosticsLogLocals',
      'textbookLocals',
      'worksheetQuestionLocals',
      'worksheetAttemptLocals',
      'parentStudentLinkLocals',
      'textbookNoteLocals',
      'textbookHighlightLocals',
      'aiChatLocals',
      'aiMessageLocals',
    ];
    for (final c in collections) {
      _collections[c] = {};
    }
  }

  Map<dynamic, dynamic> _getCollection(String name) {
    return _collections[name] ??= {};
  }

  MockQuery<T> where<T>() => MockQuery<T>(_getCollection('$T'));

  MockQuery<T> filter<T>() => MockQuery<T>(_getCollection('$T'));

  Future<void> put<T>(T obj) async {
    final id = (obj as dynamic).id ??
        (obj as dynamic).uuid?.hashCode ??
        DateTime.now().millisecondsSinceEpoch;
    _getCollection('$T')[id] = obj;
  }

  Future<void> putAll<T>(List<T> objects) async {
    for (final obj in objects) {
      await put<T>(obj);
    }
  }

  Future<T?> get<T>(dynamic id) async {
    return _getCollection('$T')[id] as T?;
  }

  Future<List<T>> getAll<T>() async {
    return _getCollection('$T').values.cast<T>().toList();
  }

  Future<bool> delete<T>(dynamic id) async {
    return _getCollection('$T').remove(id) != null;
  }

  Future<int> clear<T>() async {
    final count = _getCollection('$T').length;
    _getCollection('$T').clear();
    return count;
  }

  Future<R> writeTxn<R>(Future<R> Function() callback) async {
    return await callback();
  }

  @override
  Future<void> close() async {
    _collections.clear();
  }
}

/// In-memory mock query runner
class MockQuery<T> {
  final Map<dynamic, dynamic> _collection;
  String? _sortProperty;
  bool _sortDesc = false;

  MockQuery(this._collection);

  MockQuery<T> sortBy(String property) {
    _sortProperty = property;
    _sortDesc = false;
    return this;
  }

  MockQuery<T> sortByDesc(String property) {
    _sortProperty = property;
    _sortDesc = true;
    return this;
  }

  Future<List<T>> findAll() async {
    final items = _collection.values.cast<T>().toList();
    if (_sortProperty != null) {
      items.sort((a, b) {
        final valA = (a as dynamic).toJson?[_sortProperty] ?? '';
        final valB = (b as dynamic).toJson?[_sortProperty] ?? '';
        final cmp = Comparable.compare(valA as Comparable, valB as Comparable);
        return _sortDesc ? -cmp : cmp;
      });
    }
    return items;
  }

  Future<T?> findFirst() async {
    final all = await findAll();
    return all.isEmpty ? null : all.first;
  }

  Future<int> count() async {
    return _collection.length;
  }

  Future<bool> isEmpty() async {
    return _collection.isEmpty;
  }

  Future<bool> isNotEmpty() async {
    return _collection.isNotEmpty;
  }
}

/// Static registry / manager for Database instance
class DatabaseProvider {
  static DatabaseInterface? _instance;

  static DatabaseInterface? get instance => _instance;

  static void setInstance(DatabaseInterface? db) {
    _instance = db;
  }

  static bool get isInitialized => _instance != null;
  static bool get isWeb => kIsWeb;
}
