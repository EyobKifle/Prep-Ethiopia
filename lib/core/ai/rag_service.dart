import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService();
});

class RagService {
  Database? _db;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Load the vector extension
    sqlite3.loadSqliteVectorExtension();

    // 2. Open the database file
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDocDir.path, 'embeddings.db');
    
    _db = sqlite3.open(dbPath);

    // 3. Create tables if they don't exist
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS textbook_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        textbook_uuid TEXT,
        page_number INTEGER,
        content TEXT,
        embedding BLOB
      )
    ''');
    
    // Note: virtual table for faster vector search if needed
    // CREATE VIRTUAL TABLE vec_chunks USING vec0(embedding float[384])

    _isInitialized = true;
  }

  /// Finds relevant snippets from the local vector database.
  /// [queryVector] is the embedding of the user's question.
  Future<List<Map<String, dynamic>>> search(List<double> queryVector, {String? textbookUuid, int limit = 3}) async {
    if (!_isInitialized || _db == null) {
      throw Exception("RAG Service not initialized");
    }

    // Convert query vector to float32 blob for sqlite-vec
    // In a production app, you'd use the vector_f32() function from sqlite-vec
    
    final queryJson = queryVector.toString();
    
    String sql = '''
      SELECT textbook_uuid, page_number, content, 
             vector_distance_cos(embedding, vector_f32(?)) as distance
      FROM textbook_chunks
    ''';
    
    List<Object?> params = [queryJson];

    if (textbookUuid != null) {
      sql += ' WHERE textbook_uuid = ?';
      params.add(textbookUuid);
    }

    sql += ' ORDER BY distance ASC LIMIT ?';
    params.add(limit);

    final ResultSet results = _db!.select(sql, params);

    return results.map((row) => {
      'textbook_uuid': row['textbook_uuid'],
      'page_number': row['page_number'],
      'content': row['content'],
      'distance': row['distance'],
    }).toList();
  }

  /// Stores a chunk of text with its embedding.
  Future<void> insertChunk({
    required String textbookUuid,
    required int pageNumber,
    required String content,
    required List<double> embedding,
  }) async {
    if (_db == null) return;
    
    final embeddingJson = embedding.toString();

    _db!.execute(
      "INSERT INTO textbook_chunks (textbook_uuid, page_number, content, embedding) VALUES (?, ?, ?, vector_f32(?))",
      [textbookUuid, pageNumber, content, embeddingJson],
    );
  }

  void close() {
    _isInitialized = false;
  }
}
