import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/database/isar_models.dart';
import 'core/database/isar_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Load Environment Variables
  await dotenv.load(fileName: ".env");

  // 0.5 Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // 1. Initialize Isar Offline Database
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      GradeLocalSchema,
      SubjectLocalSchema,
      UnitLocalSchema,
      WorksheetLocalSchema,
      ExamLocalSchema,
      ExamQuestionLocalSchema,
      LessonLocalSchema,
      StepLocalSchema,
      QuizQuestionLocalSchema,
      FlashcardTemplateLocalSchema,
      ProfileLocalSchema,
      UserProgressLocalSchema,
      QuizAttemptLocalSchema,
      ExamAttemptLocalSchema,
      UserFlashcardLocalSchema,
      FeatureFlagLocalSchema,
      AppDiagnosticsLogLocalSchema,
      TextbookLocalSchema,
      WorksheetQuestionLocalSchema,
      WorksheetAttemptLocalSchema,
      ParentStudentLinkLocalSchema,
      TextbookNoteLocalSchema,
      TextbookHighlightLocalSchema,
      AiChatLocalSchema,
      AiMessageLocalSchema,
    ],
    directory: dir.path,
  );

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const PrepEthiopiaApp(),
    ),
  );
}

class PrepEthiopiaApp extends ConsumerWidget {
  const PrepEthiopiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Prep Ethiopia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
