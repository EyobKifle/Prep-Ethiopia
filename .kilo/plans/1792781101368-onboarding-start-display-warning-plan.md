# Plan: Fix Onboarding Start/Display & Warnings

## Goal
Make the app start and display all onboarding details instead of only showing content text, and replace noisy debug logging with a proper user-facing warning.

## Issues
1. `OnboardingScreenState` logs `_nextStep called!` and `dispose!` to console; no user feedback.
2. App shows setup progress text but doesn't render full details; should display complete onboarding content.
3. No warning shown when sync/setup fails; only a snackbar for missing grade.

## Proposed Changes
- Remove `debugPrint` statements in `onboarding_screen.dart` (`_nextStep`, `dispose`, `_startSimulatedDownload`).
- Add a visible warning banner when `_setupFailed` is true (replace silent failure).
- Ensure `_buildDownloadStep` renders all details (grade, language, progress, status) regardless of sync state.
- Gate `_continueToDashboard` behind explicit user action on failure; show retry option.
- Add a splash/loading guard so app displays onboarding content immediately on start.

## Affected Files
- `lib/features/auth/presentation/onboarding_screen.dart`
- `lib/core/router/app_router.dart` (splash guard)
- `test/onboarding_test.dart` (update assertions)

## Validation
- Run `flutter test test/onboarding_test.dart`.
- Manual: launch app, verify onboarding content displays fully and warning appears on sync failure.

## Open Questions
- Should warning be a SnackBar or inline banner? Recommend inline banner.
- Should app block navigation until sync completes? Recommend allow continue with warning.
