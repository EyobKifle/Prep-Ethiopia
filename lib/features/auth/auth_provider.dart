import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, AuthResponse, AuthException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/database/isar_models.dart';
import '../../core/database/isar_provider.dart';
import '../../core/network/remote_api_service.dart';
import '../../core/network/api_models.dart';

/// Minimal auth representation for this app (no Supabase SDK).
class AppUser {
  final String id;
  final String token;

  const AppUser({required this.id, required this.token});
}

class AuthState {
  final AppUser? user;
  final ProfileLocal? profile;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AppUser? user,
    ProfileLocal? profile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final RemoteApiService _api;
  final Isar _isar;
  final SupabaseClient? _supabase;
  final bool _hasSupabase;

  AuthNotifier(this._api, this._isar, {SupabaseClient? supabase})
      : _supabase = supabase,
        _hasSupabase = supabase != null,
        super(AuthState()) {
    _init();
  }

  SupabaseClient get _client {
    if (_hasSupabase && _supabase != null) {
      return _supabase!;
    }
    return Supabase.instance.client;
  }

  bool get _supabaseInitialized {
    if (_hasSupabase && _supabase != null) {
      return true;
    }
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _init() {
    if (!_supabaseInitialized) {
      debugPrint('Supabase not initialized - running in offline mode');
      return;
    }

    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _loadProfile(session.user.id, session.accessToken);
      } else {
        state = AuthState();
      }
    });

    loadInitialSession();
  }

  Future<void> loadInitialSession() async {
    if (!_supabaseInitialized) return;
    
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        await _loadProfile(session.user.id, session.accessToken);
      }
    } catch (_) {
      // Ignore errors in offline mode
    }
  }

  Future<void> _loadProfile(String userId, String token) async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _isar.profileLocals.filter().uuidEqualTo(userId).findFirst();
      if (profile != null) {
        state = AuthState(
          user: AppUser(id: userId, token: token),
          profile: profile,
          isLoading: false,   // ← explicitly reset
        );
      } else {
        // Try to pull from remote
        try {
          final remoteData = await _api.pullRemoteProgress(userId: userId, since: DateTime(2000));
          final remoteProfiles = remoteData['profiles'] as List?;
          if (remoteProfiles != null && remoteProfiles.isNotEmpty) {
            final p = remoteProfiles.first;
            final profile = ProfileLocal()
              ..uuid = userId
              ..role = p['role'] ?? 'student'
              ..fullName = p['full_name']
              ..phoneNumber = p['phone_number']
              ..preferredLanguage = p['preferred_language'] ?? 'en'
              ..selectedGradeLevel = p['selected_grade_level']
              ..isDirty = false
              ..updatedAt = DateTime.now();

            await _isar.writeTxn(() async => await _isar.profileLocals.put(profile));
            state = AuthState(
              user: AppUser(id: userId, token: token),
              profile: profile,
              isLoading: false,   // ← explicitly reset
            );
          } else {
            // No profile found remotely either — stop loading
            state = state.copyWith(isLoading: false);
          }
        } catch (_) {
          state = state.copyWith(isLoading: false);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> signIn(String email, String password) async {
    final guestUuid = state.profile?.uuid;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.signIn(email: email, password: password);

if (response.accessToken != null && response.refreshToken != null && response.user != null) {
        final userId = (response.user as Map)['id'] as String;
        _api.setAuthToken(response.accessToken);
        if (_supabaseInitialized) {
          await _client.auth.setSession(response.accessToken!);
        }
        await _loadProfile(userId, response.accessToken!);
        await _mergeGuestProgressIfNeeded(guestUuid, userId);
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String errorMessage = _getErrorMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
      return false;
    }
  }

  Future<bool> signUp(
    String email,
    String password,
    String fullName,
    String phoneNumber,
    String preferredLang, {
    String role = 'student',
  }) async {
    final guestUuid = state.profile?.uuid;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        preferredLanguage: preferredLang,
        role: role,
      );

      if (response.requireSignin == true || response.refreshToken == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message ?? 'Account created! Please sign in to continue.',
        );
        return false;
      }

      if (response.accessToken != null && response.refreshToken != null && response.user != null) {
        final userId = (response.user as Map)['id'] as String;
        _api.setAuthToken(response.accessToken);
        if (_supabaseInitialized) {
          await _client.auth.setSession(response.accessToken!);
        }
        await _loadProfile(userId, response.accessToken!);
        await _mergeGuestProgressIfNeeded(guestUuid, userId);
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String errorMessage = _getErrorMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.forgotPassword(email: email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String errorMessage = _getErrorMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
      return false;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is NetworkException) {
      return 'Network connection failed. Please check your internet.';
    } else if (error is AuthException) {
      return error.message;
    } else if (error is RateLimitException) {
      return 'Too many attempts. Please try again later.';
    } else if (error is ServerException) {
      return 'Internal Server Error. Please try again later.';
    } else if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> signOut() async {
    if (_supabaseInitialized) {
      await _client.auth.signOut();
    }

    // For now, wipe local progress logs to keep user privacy.
    await _isar.writeTxn(() async {
      await _isar.profileLocals.clear();
      await _isar.userProgressLocals.clear();
      await _isar.quizAttemptLocals.clear();
      await _isar.examAttemptLocals.clear();
      await _isar.userFlashcardLocals.clear();
    });
    state = AuthState();
  }

  void setGuestSession(ProfileLocal profile) {
    state = AuthState(user: null, profile: profile);
  }

  Future<void> updateProfile(ProfileLocal profile) async {
    await _isar.writeTxn(() async {
      await _isar.profileLocals.put(profile);
    });
    state = state.copyWith(profile: profile);
  }

  Future<void> _mergeGuestProgressIfNeeded(
    String? guestUuid,
    String newUserUuid,
  ) async {
    if (guestUuid == null || !guestUuid.startsWith('guest_')) return;
    try {
      await mergeGuestProgress(guestUuid, newUserUuid);
    } catch (e) {
      debugPrint('Could not carry guest progress into the account: $e');
    }
  }

  Future<void> mergeGuestProgress(String guestUuid, String newUserUuid) async {
    await _isar.writeTxn(() async {
      final progressRecords = await _isar.userProgressLocals.filter().userUuidEqualTo(guestUuid).findAll();
      for (final record in progressRecords) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.userProgressLocals.put(record);
      }

      final quizAttempts = await _isar.quizAttemptLocals.filter().userUuidEqualTo(guestUuid).findAll();
      for (final record in quizAttempts) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.quizAttemptLocals.put(record);
      }

      final examAttempts = await _isar.examAttemptLocals.filter().userUuidEqualTo(guestUuid).findAll();
      for (final record in examAttempts) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.examAttemptLocals.put(record);
      }

      final worksheetAttempts = await _isar.worksheetAttemptLocals.filter().userUuidEqualTo(guestUuid).findAll();
      for (final record in worksheetAttempts) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.worksheetAttemptLocals.put(record);
      }

      final textbookNotes = await _isar.textbookNoteLocals.filter().userUuidEqualTo(guestUuid).findAll();
      for (final record in textbookNotes) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.textbookNoteLocals.put(record);
      }

      final textbookHighlights = await _isar.textbookHighlightLocals.filter().userUuidEqualTo(guestUuid).findAll();
      for (final record in textbookHighlights) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.textbookHighlightLocals.put(record);
      }

      final aiChats = await _isar.aiChatLocals.filter().userUuidEqualTo(guestUuid).findAll();
      final chatUuids = aiChats.map((c) => c.uuid).toList();
      for (final record in aiChats) {
        record.userUuid = newUserUuid;
        record.isDirty = true;
        await _isar.aiChatLocals.put(record);
      }

      if (chatUuids.isNotEmpty) {
        final aiMessages = await _isar.aiMessageLocals
            .filter()
            .anyOf(chatUuids, (q, String chatUuid) => q.chatUuidEqualTo(chatUuid))
            .findAll();
        for (final record in aiMessages) {
          record.chatUuid = newUserUuid;
          record.isDirty = true;
          await _isar.aiMessageLocals.put(record);
        }
      }

      final parentLinks = await _isar.parentStudentLinkLocals.filter().parentUuidEqualTo(guestUuid).findAll();
      for (final record in parentLinks) {
        record.parentUuid = newUserUuid;
        record.isDirty = true;
        await _isar.parentStudentLinkLocals.put(record);
      }

      final studentLinks = await _isar.parentStudentLinkLocals.filter().studentUuidEqualTo(guestUuid).findAll();
      for (final record in studentLinks) {
        record.studentUuid = newUserUuid;
        record.isDirty = true;
        await _isar.parentStudentLinkLocals.put(record);
      }
    });
  }

  Future<bool> hasLinkedChildren(String parentUuid) async {
    final count = await _isar.parentStudentLinkLocals.filter().parentUuidEqualTo(parentUuid).count();
    return count > 0;
  }
}

final remoteApiServiceProvider = Provider<RemoteApiService>((ref) {
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  final hasValidConfig = supabaseUrl.isNotEmpty && 
      supabaseKey.isNotEmpty && 
      !supabaseUrl.contains('your-project') && 
      !supabaseKey.contains('your-anon-key');
  
  if (hasValidConfig) {
    final baseUrl = '$supabaseUrl/functions/v1/dynamic-api';
    return RemoteApiService(baseUrl: baseUrl, apiKey: supabaseKey);
  } else {
    // Return a mock/placeholder service that will fail gracefully
    return RemoteApiService(baseUrl: '', apiKey: '');
  }
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(remoteApiServiceProvider);
  final isar = ref.watch(isarProvider);
  final hasValidConfig = (dotenv.env['SUPABASE_URL'] ?? '').isNotEmpty && 
      (dotenv.env['SUPABASE_ANON_KEY'] ?? '').isNotEmpty && 
      !(dotenv.env['SUPABASE_URL'] ?? '').contains('your-project') && 
      !(dotenv.env['SUPABASE_ANON_KEY'] ?? '').contains('your-anon-key');
  
  SupabaseClient? supabaseClient;
  if (hasValidConfig) {
    try {
      supabaseClient = Supabase.instance.client;
    } catch (_) {
      // Supabase not initialized
    }
  }
  return AuthNotifier(api, isar, supabase: supabaseClient);
});
