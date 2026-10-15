import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mocktail/mocktail.dart';
import 'package:isar_community/isar.dart';

import 'package:prep_ethiopia/features/auth/presentation/onboarding_screen.dart';
import 'package:prep_ethiopia/features/auth/auth_provider.dart';
import 'package:prep_ethiopia/core/database/isar_provider.dart';
import 'package:prep_ethiopia/core/localization/app_localizations.dart';
import 'package:prep_ethiopia/core/network/remote_api_service.dart';

class MockIsar extends Mock implements Isar {}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('Test lifecycle on tap student', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeIsar = MockIsar();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarProvider.overrideWithValue(fakeIsar),
          authProvider.overrideWith((_) => AuthNotifier(
                RemoteApiService(baseUrl: 'http://localhost', apiKey: 'test'),
                fakeIsar,
              )),
          localeProvider.overrideWith((ref) => LocaleNotifier(AuthState(), ref)),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    debugPrint('--- Now tapping student InkWell ---');
    final inkWells = find.byType(InkWell);
    await tester.tap(inkWells.first);

    debugPrint('--- Pump 1 ---');
    await tester.pump();
    debugPrint('--- Pump 2 (100ms) ---');
    await tester.pump(const Duration(milliseconds: 100));
    debugPrint('--- Pump 3 (100ms) ---');
    await tester.pump(const Duration(milliseconds: 100));
    debugPrint('--- Pump 4 (100ms) ---');
    await tester.pump(const Duration(milliseconds: 100));
    debugPrint('--- Settle ---');
    await tester.pumpAndSettle();
  });
}
