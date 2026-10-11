import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;
import 'package:dio/dio.dart';
import 'api_models.dart';

class RemoteApiService {
  final Dio _dio = Dio();
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  RemoteApiService({
    required String baseUrl,
    required String apiKey,
  }) {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers = {
      'apikey': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));
  }

  // Generic invoker for the monolith Edge Function
  Future<dynamic> _invoke(String path, {String method = 'POST', Map<String, dynamic>? body, Map<String, dynamic>? query}) async {
    try {
      if (_authToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $_authToken';
      } else {
        _dio.options.headers.remove('Authorization');
      }

      final response = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );

      return response.data;
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data;
        throw ApiException(
          message: errorData is Map ? errorData['error'] ?? e.message : e.message,
          statusCode: e.response?.statusCode,
        );
      }
      rethrow;
    }
  }

  // Auth Methods
  Future<AuthResponse> signIn({required String email, required String password}) async {
    final data = await _invoke('/auth/sign-in', body: {
      'email': email,
      'password': password,
    });

    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phoneNumber,
    String? preferredLanguage,
    String role = 'student',
  }) async {
    final data = await _invoke('/auth/sign-up', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'preferred_language': preferredLanguage,
      'role': role,
    });

    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<void> forgotPassword({required String email}) async {
    await _invoke('/auth/forgot-password', body: {
      'email': email,
    });
  }

  Future<Map<String, dynamic>> fetchAppSettings() async {
    final data = await _invoke('/admin/settings', method: 'GET');
    return data as Map<String, dynamic>;
  }

  // Curriculum Methods
  Future<List<FeatureFlag>> fetchFeatureFlags() async {
    final data = await _invoke('/curriculum/feature-flags', method: 'GET');
    if (data is List) {
      return data.map((e) => FeatureFlag.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchCurriculumIncremental({required DateTime since, int? gradeLevel}) async {
    final query = {'since': since.toIso8601String()};
    if (gradeLevel != null) {
      query['grade_level'] = gradeLevel.toString();
    }
    final data = await _invoke('/curriculum/incremental', method: 'GET', query: query);
    return data as Map<String, dynamic>;
  }

  // Progress Methods
  Future<void> pushUserProgress({
    required String userId,
    List<Map<String, dynamic>>? userProgress,
    List<Map<String, dynamic>>? quizAttempts,
    List<Map<String, dynamic>>? examAttempts,
    List<Map<String, dynamic>>? userFlashcards,
    List<Map<String, dynamic>>? profiles,
    List<Map<String, dynamic>>? worksheetAttempts,
    List<Map<String, dynamic>>? parentStudentLinks,
    List<Map<String, dynamic>>? textbookNotes,
    List<Map<String, dynamic>>? textbookHighlights,
  }) async {
    await _invoke('/sync/push-progress', body: {
      'user_id': userId,
      'user_progress': userProgress,
      'quiz_attempts': quizAttempts,
      'exam_attempts': examAttempts,
      'user_flashcards': userFlashcards,
      'profiles': profiles,
      'worksheet_attempts': worksheetAttempts,
      'parent_student_links': parentStudentLinks,
      'textbook_notes': textbookNotes,
      'textbook_highlights': textbookHighlights,
    });
  }

  Future<Map<String, dynamic>> pullRemoteProgress({required String userId, required DateTime since}) async {
    final data = await _invoke('/sync/pull-progress', method: 'GET', query: {
      'user_id': userId,
      'since': since.toIso8601String(),
    });
    return data as Map<String, dynamic>;
  }

  // --- Admin Curriculum Sync ---
  Future<void> pushCurriculum({
    List<Map<String, dynamic>>? grades,
    List<Map<String, dynamic>>? subjects,
    List<Map<String, dynamic>>? units,
    List<Map<String, dynamic>>? lessons,
    List<Map<String, dynamic>>? steps,
    List<Map<String, dynamic>>? quizQuestions,
    List<Map<String, dynamic>>? exams,
    List<Map<String, dynamic>>? examQuestions,
    List<Map<String, dynamic>>? flashcards,
    List<Map<String, dynamic>>? textbooks,
    List<Map<String, dynamic>>? worksheets,
  }) async {
    await _invoke('/curriculum/push', body: {
      'grades': grades,
      'subjects': subjects,
      'units': units,
      'lessons': lessons,
      'steps': steps,
      'quiz_questions': quizQuestions,
      'exams': exams,
      'exam_questions': examQuestions,
      'flashcards': flashcards,
      'textbooks': textbooks,
      'worksheets': worksheets,
    });
  }

  // --- Admin User Management ---
  Future<List<Map<String, dynamic>>> fetchAdminUserList() async {
    final data = await _invoke('/admin/users/list', method: 'GET');
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> updateUserRole({required String userUuid, required String role}) async {
    await _invoke('/admin/users/update-role', body: {
      'user_id': userUuid,
      'role': role,
    });
  }

  // --- Parent Progress Methods ---
  Future<List<Map<String, dynamic>>> fetchChildProgress({required String studentUuid}) async {
    final data = await _invoke('/parent/child-progress', method: 'GET', query: {'student_id': studentUuid});
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> verifyLinkCode({required String code}) async {
    final data = await _invoke('/parent/verify-link', body: {'code': code});
    return data as Map<String, dynamic>;
  }

  // Storage Methods
  Future<String> uploadFile({
    required Uint8List bytes,
    required String bucket,
    required String filename,
    Function(int, int)? onSendProgress,
  }) async {
    final supabase = Supabase.instance.client;
    await supabase.storage.from(bucket).uploadBinary(
          filename,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return supabase.storage.from(bucket).getPublicUrl(filename);
  }

  Future<Uint8List> downloadFile(String url, {void Function(int, int)? onReceiveProgress}) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onReceiveProgress,
      );
      if (response.data == null) {
        throw ApiException(message: 'Download failed: No data');
      }
      return Uint8List.fromList(response.data!);
    } catch (e) {
      if (e is DioException) {
        throw ApiException(
          message: 'Download error: ${e.message}',
          statusCode: e.response?.statusCode,
        );
      }
      rethrow;
    }
  }
}
