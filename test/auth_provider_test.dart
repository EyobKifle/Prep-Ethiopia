import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:lumo/features/auth/auth_provider.dart';
import 'package:lumo/core/network/remote_api_service.dart';
import 'package:lumo/core/network/api_models.dart' as api;
import 'package:lumo/core/database/isar_models.dart';

class MockRemoteApiService extends Mock implements RemoteApiService {}
class MockIsar extends Mock implements Isar {}
class MockSupabaseClient extends Mock implements supabase.SupabaseClient {}
class MockGoTrueClient extends Mock implements supabase.GoTrueClient {}
class MockProfileCollection extends Mock implements IsarCollection<ProfileLocal> {}
class MockUserProgressCollection extends Mock implements IsarCollection<UserProgressLocal> {}
class MockQuizAttemptCollection extends Mock implements IsarCollection<QuizAttemptLocal> {}
class MockExamAttemptCollection extends Mock implements IsarCollection<ExamAttemptLocal> {}
class MockUserFlashcardCollection extends Mock implements IsarCollection<UserFlashcardLocal> {}

void main() {
  late AuthNotifier authNotifier;
  late MockRemoteApiService mockApi;
  late MockIsar mockIsar;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late MockProfileCollection mockProfileCollection;

  setUpAll(() {
    registerFallbackValue(ProfileLocal());
  });

  setUp(() {
    mockApi = MockRemoteApiService();
    mockIsar = MockIsar();
    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    mockProfileCollection = MockProfileCollection();

    when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    when(() => mockGoTrue.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => mockGoTrue.currentSession).thenReturn(null);
    when(() => mockIsar.writeTxn(any())).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as Future<void> Function();
      return callback();
    });
  });

  test('Initial state is correct', () {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);
    expect(authNotifier.state.user, isNull);
    expect(authNotifier.state.profile, isNull);
    expect(authNotifier.state.isLoading, isFalse);
  });

  test('signIn fails and sets error message', () async {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);
    
    when(() => mockApi.signIn(email: 'test@test.com', password: 'password'))
        .thenThrow(api.ApiException(message: 'Invalid credentials'));

    final result = await authNotifier.signIn('test@test.com', 'password');

    expect(result, isFalse);
    expect(authNotifier.state.errorMessage, 'Invalid credentials');
    expect(authNotifier.state.isLoading, isFalse);
  });

  test('signOut clears state and Isar', () async {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);
    
    when(() => mockGoTrue.signOut()).thenAnswer((_) async {});
    when(() => mockIsar.profileLocals).thenReturn(mockProfileCollection);
    when(() => mockProfileCollection.clear()).thenAnswer((_) async => 0);
    
    final mockProgress = MockUserProgressCollection();
    final mockQuiz = MockQuizAttemptCollection();
    final mockExam = MockExamAttemptCollection();
    final mockFlashcard = MockUserFlashcardCollection();
    
    when(() => mockIsar.userProgressLocals).thenReturn(mockProgress);
    when(() => mockIsar.quizAttemptLocals).thenReturn(mockQuiz);
    when(() => mockIsar.examAttemptLocals).thenReturn(mockExam);
    when(() => mockIsar.userFlashcardLocals).thenReturn(mockFlashcard);

    when(() => mockProgress.clear()).thenAnswer((_) async => 0);
    when(() => mockQuiz.clear()).thenAnswer((_) async => 0);
    when(() => mockExam.clear()).thenAnswer((_) async => 0);
    when(() => mockFlashcard.clear()).thenAnswer((_) async => 0);

    await authNotifier.signOut();

    expect(authNotifier.state.user, isNull);
    expect(authNotifier.state.profile, isNull);
    verify(() => mockGoTrue.signOut()).called(1);
    verify(() => mockProfileCollection.clear()).called(1);
  });

  test('setGuestSession sets profile and null user', () {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);
    final profile = ProfileLocal()
      ..uuid = 'guest'
      ..role = 'student'
      ..preferredLanguage = 'en'
      ..isDirty = false
      ..updatedAt = DateTime.now();
    
    authNotifier.setGuestSession(profile);
    
    expect(authNotifier.state.user, isNull);
    expect(authNotifier.state.profile, profile);
  });

  test('updateProfile saves to Isar and updates state', () async {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);
    final profile = ProfileLocal()
      ..uuid = 'user1'
      ..role = 'student'
      ..preferredLanguage = 'en'
      ..isDirty = false
      ..updatedAt = DateTime.now();
    
    when(() => mockIsar.profileLocals).thenReturn(mockProfileCollection);
    when(() => mockProfileCollection.put(any())).thenAnswer((_) async => 0);

    await authNotifier.updateProfile(profile);

    expect(authNotifier.state.profile, profile);
    verify(() => mockProfileCollection.put(profile)).called(1);
  });

  test('signUp handles requireSignin response', () async {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);
    
    final signUpResponse = api.AuthResponse(
      requireSignin: true,
      message: 'Please verify your email',
    );

    when(() => mockApi.signUp(
      email: 'new@test.com',
      password: 'password',
      fullName: 'New User',
      phoneNumber: '123',
      preferredLanguage: 'en',
    )).thenAnswer((_) async => signUpResponse);

    final result = await authNotifier.signUp(
      'new@test.com',
      'password',
      'New User',
      '123',
      'en',
    );

    expect(result, isFalse);
    expect(authNotifier.state.errorMessage, 'Please verify your email');
    expect(authNotifier.state.isLoading, isFalse);
  });

  test('signUp success calls setSession', () async {
    authNotifier = AuthNotifier(mockApi, mockIsar, supabase: mockSupabase);

    final authResponse = api.AuthResponse(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: {'id': 'user123'},
    );

    when(() => mockApi.signUp(
          email: 'new@test.com',
          password: 'password',
          fullName: 'New User',
          phoneNumber: '123',
          preferredLanguage: 'en',
        )).thenAnswer((_) async => authResponse);

    when(() => mockGoTrue.setSession(any()))
        .thenAnswer((_) async => supabase.AuthResponse());

    when(() => mockIsar.profileLocals).thenReturn(mockProfileCollection);

    final result = await authNotifier.signUp(
      'new@test.com',
      'password',
      'New User',
      '123',
      'en',
    );

    expect(result, isTrue);
    verify(() => mockGoTrue.setSession(any())).called(1);
  });
}
