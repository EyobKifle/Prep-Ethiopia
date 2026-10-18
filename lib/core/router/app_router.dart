import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';

import '../../features/student/presentation/shell/student_shell.dart';
import '../../features/student/presentation/dashboard/student_dashboard_screen.dart';
import '../../features/student/presentation/search/search_screen.dart';
import '../../features/student/presentation/analysis/analysis_screen.dart';
import '../../features/student/presentation/subject/subject_detail_screen.dart';
import '../../features/student/presentation/subject/textbook_viewer_screen.dart';
import '../../features/student/presentation/lesson/lesson_reading_screen.dart';
import '../../features/student/presentation/lesson/lesson_quiz_screen.dart';
import '../../features/student/presentation/lesson/lesson_flashcard_screen.dart';
import '../../features/student/presentation/exercises/worksheet_list_screen.dart';
import '../../features/student/presentation/exercises/worksheet_exercise_screen.dart';
import '../../features/student/presentation/exercises/answer_review_screen.dart';
import '../../features/student/presentation/library/offline_library_screen.dart';
import '../../features/student/presentation/profile/student_profile_screen.dart';
import '../../features/student/presentation/ai_tutor/ai_tutor_screen.dart';

import '../../features/admin/presentation/shell/admin_shell.dart';
import '../../features/admin/presentation/content/content_manager_screen.dart';
import '../../features/admin/presentation/content/lesson_editor_screen.dart';
import '../../features/admin/presentation/content/worksheet_editor_screen.dart';
import '../../features/admin/presentation/content/quiz_question_editor_screen.dart';
import '../../features/admin/presentation/overview/admin_diagnostics_screen.dart';
import '../../features/admin/presentation/users/user_management_screen.dart';

import '../../features/parent/presentation/shell/parent_shell.dart';
import '../../features/parent/presentation/dashboard/parent_dashboard_screen.dart';
import '../../features/parent/presentation/dashboard/child_progress_screen.dart';
import '../../features/parent/presentation/link/link_child_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state to reactively trigger router redirects on auth state change
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      // Prevent redirect loops / incorrect onboarding during async auth init
      if (auth.isLoading) return null;

      final profile = auth.profile;
      final hasProfile = profile != null;
      final isSignedIn = auth.user != null;

      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding';

      // 1. If not signed in and no profile, force onboarding (or allow only auth entry routes)
      if (!isSignedIn && !hasProfile && !isLoggingIn) {
        return '/onboarding';
      }

      // 2. If already has profile, prevent access to login/signup/onboarding
      //    BUT allow students (signed-in or guest) with incomplete profiles to stay.
      if ((isSignedIn || hasProfile) && isLoggingIn) {
        if (profile == null) return '/onboarding';

        final role = profile.role;

        // Allow students with incomplete profiles to continue onboarding
        if (role == 'student') {
          if (profile.selectedGradeLevel == null || profile.preferredLanguage.isEmpty) {
            return null; // Stay on onboarding
          }
        }

        if (role == 'admin' || role == 'teacher') return '/admin';
        if (role == 'parent') return '/parent';
        return '/student';
      }

      // 3. Role-based route guard redirects (only when profile is available)
      if (hasProfile) {
        final loc = state.matchedLocation;
        final role = profile.role;

        // Prevent cross-access based on roles
        if (loc.startsWith('/admin') && (role != 'admin' && role != 'teacher')) {
          return role == 'parent' ? '/parent' : '/student';
        }
        if (loc.startsWith('/parent') && role != 'parent') {
          return (role == 'admin' || role == 'teacher') ? '/admin' : '/student';
        }
        if (loc.startsWith('/student') && (role == 'admin' || role == 'teacher')) {
          return '/admin';
        }
        if (loc.startsWith('/student') && role == 'parent') {
          return '/parent';
        }

        // Resume incomplete onboarding for signed-in users
        if (!isSignedIn && loc != '/onboarding') {
          return '/onboarding';
        }
        if (isSignedIn && role == 'student') {
          if (profile.selectedGradeLevel == null || profile.preferredLanguage.isEmpty) {
            return '/onboarding';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'student';
          return SignupScreen(role: role);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          final testRole = state.uri.queryParameters['testRole'];
          final guestMode = state.uri.queryParameters['guest'] == 'true';
          return OnboardingScreen(testRole: testRole, guestMode: guestMode);
        },
      ),

      // -------------------------------------------------------------
      // STUDENT PORTAL ROUTING (Wrapped in StudentShell)
      // -------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const StudentDashboardScreen(),
          ),
          GoRoute(
            path: '/student/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/student/analysis',
            builder: (context, state) => const AnalysisScreen(),
          ),
          GoRoute(
            path: '/student/subject/:subjectId',
            builder: (context, state) {
              final subjectId = state.pathParameters['subjectId']!;
              return SubjectDetailScreen(subjectUuid: subjectId);
            },
          ),
          GoRoute(
            path: '/student/exercises',
            builder: (context, state) => const WorksheetListScreen(),
          ),
          GoRoute(
            path: '/student/attempts',
            builder: (context, state) => const AnswerReviewScreen(),
          ),
          GoRoute(
            path: '/student/library',
            builder: (context, state) => const OfflineLibraryScreen(),
          ),
          GoRoute(
            path: '/student/profile',
            builder: (context, state) => const StudentProfileScreen(),
          ),
          GoRoute(
            path: '/student/ai-tutor',
            builder: (context, state) {
              final textbookUuid = state.uri.queryParameters['textbookUuid'];
              final lessonUuid = state.uri.queryParameters['lessonUuid'];
              return AiTutorScreen(
                textbookUuid: textbookUuid,
                lessonUuid: lessonUuid,
              );
            },
          ),
        ],
      ),

      // Full-screen student flows (outside main student shell)
      GoRoute(
        path: '/student/textbook/:textbookId',
        builder: (context, state) {
          final textbookId = state.pathParameters['textbookId']!;
          return TextbookViewerScreen(textbookUuid: textbookId);
        },
      ),
      GoRoute(
        path: '/student/lesson/:lessonId/reading/:stepId',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          final stepId = state.pathParameters['stepId']!;
          return LessonReadingScreen(lessonUuid: lessonId, stepUuid: stepId);
        },
      ),
      GoRoute(
        path: '/student/lesson/:lessonId/quiz/:stepId',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          final stepId = state.pathParameters['stepId']!;
          return LessonQuizScreen(lessonUuid: lessonId, stepUuid: stepId);
        },
      ),
      GoRoute(
        path: '/student/lesson/:lessonId/flashcards/:stepId',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          final stepId = state.pathParameters['stepId']!;
          return LessonFlashcardScreen(lessonUuid: lessonId, stepUuid: stepId);
        },
      ),
      GoRoute(
        path: '/student/worksheet/:worksheetId',
        builder: (context, state) {
          final worksheetId = state.pathParameters['worksheetId']!;
          return WorksheetExerciseScreen(worksheetUuid: worksheetId);
        },
      ),

      // -------------------------------------------------------------
      // ADMIN DASHBOARD ROUTING (Wrapped in AdminShell)
      // -------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDiagnosticsScreen(),
          ),
          GoRoute(
            path: '/admin/content',
            builder: (context, state) => const ContentManagerScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/lesson-editor/:lessonId',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return LessonEditorScreen(lessonUuid: lessonId);
        },
      ),
      GoRoute(
        path: '/admin/worksheet-editor/:worksheetId',
        builder: (context, state) {
          final worksheetId = state.pathParameters['worksheetId']!;
          return WorksheetEditorScreen(worksheetUuid: worksheetId);
        },
      ),
      GoRoute(
        path: '/admin/quiz-editor/:stepId',
        builder: (context, state) {
          final stepId = state.pathParameters['stepId']!;
          return QuizQuestionEditorScreen(stepUuid: stepId);
        },
      ),

      // -------------------------------------------------------------
      // PARENT PORTAL ROUTING (Wrapped in ParentShell)
      // -------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) => ParentShell(child: child),
        routes: [
          GoRoute(
            path: '/parent',
            builder: (context, state) => const ParentDashboardScreen(),
          ),
          GoRoute(
            path: '/parent/link',
            builder: (context, state) => const LinkChildScreen(),
          ),
          GoRoute(
            path: '/parent/child/:studentId',
            builder: (context, state) {
              final studentId = state.pathParameters['studentId']!;
              return ChildProgressScreen(studentUuid: studentId);
            },
          ),
        ],
      ),
    ],
  );
});
