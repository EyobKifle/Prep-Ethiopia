import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mocktail/mocktail.dart';
import 'package:isar_community/isar.dart';
import 'package:go_router/go_router.dart';

import 'package:lumo/main.dart';
import 'package:lumo/features/auth/auth_provider.dart';
import 'package:lumo/core/database/isar_provider.dart';
import 'package:lumo/core/router/app_router.dart';
import 'package:lumo/core/theme/app_theme.dart';
import 'package:lumo/core/localization/app_localizations.dart';
import 'package:lumo/features/sync/sync_service.dart';
import 'package:lumo/core/network/connectivity_service.dart';
import 'package:lumo/core/network/remote_api_service.dart';

class MockIsar extends Mock implements Isar {}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final fakeIsar = MockIsar();
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(fakeIsar),
        authProvider.overrideWith((_) => AuthNotifier(
              RemoteApiService(baseUrl: 'http://localhost', apiKey: 'test'),
              fakeIsar,
            )),
        routerProvider.overrideWith((_) => GoRouter(routes: [])),
        themeProvider.overrideWith((_) => ThemeNotifier()),
        localeProvider.overrideWith((ref) => LocaleNotifier(AuthState(), ref)),
        syncProvider.overrideWith((ref) => SyncNotifier(fakeIsar, ref)),
        connectivityProvider.overrideWith((_) => ConnectivityNotifier()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PrepEthiopiaApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
