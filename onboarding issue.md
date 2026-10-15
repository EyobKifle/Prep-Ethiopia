Onboarding Flow Architecture
The OnboardingScreen uses a PageView with 4 pages (0-indexed):

┌─────────────────────────────────────────────────────────────────┐
│  Page 0: Welcome / Role Selection                             │
│           → "Student" → _nextStep() → Page 1                   │
│           → "Parent"  → context.go('/signup?role=parent')     │
│           → "Teacher" → context.go('/signup?role=teacher')    │
│                                                                 │
│  Page 1: Language Selection                                     │
│           → "Amharic" → setLocale('am') + _nextStep() → Page 2 │
│           → "English" → setLocale('en') + _nextStep() → Page 2 │
│                                                                 │
│  Page 2: Grade Selection (GridView: Grades 7-12)               │
│           → Tap grade → _nextStep() → Page 3                   │
│                                                                 │
│  Page 3: Download (Simulated sync → context.go('/student'))    │
└─────────────────────────────────────────────────────────────────┘
All 4 Pages Verified to Exist
Page	Builder Method	Content	Exists
0	_buildWelcomeStep	Role cards (Student/Parent/Teacher) + Login link	✅
1	_buildLanguageStep	Amharic/English language cards	✅
2	_buildGradeStep	GridView with grades 7-12	✅
3	_buildDownloadStep	Download progress bar + percentage	✅
No duplication exists in the PageView children list — the 4 pages are correctly ordered and each is a distinct builder method.

Bugs Found
Bug 1: Router Rule 2 Fires Before Rule 3 (Critical — Blocks Signed-In Users)
File: lib/core/router/app_router.dart, lines 44-99

// Rule 2 (line 62): Fires FIRST for any profile
if ((isSignedIn || hasProfile) && isLoggingIn) {   // ← catches signed-in w/ incomplete profile
    final role = profile!.role;                       // ← CRASHES if profile is null
    return '/student';                                // ← redirects away from onboarding
}

// Rule 3 (line 70): NEVER reached for signed-in users
if (hasProfile) {
    if (isSignedIn && role == 'student') {
        if (profile.selectedGradeLevel == null || profile.preferredLanguage.isEmpty) {
            return '/onboarding';  // ← DEAD CODE for signed-in users
        }
    }
}
Impact:

A signed-in student with preferredLanguage set but selectedGradeLevel == null is sent to /student instead of /onboarding — Rule 2 intercepts before Rule 3's guard.
If isSignedIn=true but hasProfile=false, the profile!.role at line 63 throws a NullPointerException.
Bug 2: _resumeFromExistingProfile() Ignores Guest Profiles
File: lib/features/auth/presentation/onboarding_screen.dart, lines 46-70

void _resumeFromExistingProfile() {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;

    final hasLanguage = profile.preferredLanguage.isNotEmpty;
    final hasGrade = profile.selectedGradeLevel != null;
    if (hasGrade) { _selectedGrade = profile.selectedGradeLevel; }

    final isSignedIn = ref.read(authProvider).user != null;

    if (isSignedIn) {           // ← Only signed-in users! Guests fall through.
        if (hasLanguage && hasGrade) { _currentStep = 3; }
        else if (hasLanguage) { _currentStep = 2; }
        else { _currentStep = 1; }
    }
}
Impact: A guest (not signed in) with a profile is always sent to step 0 (welcome), even if they already completed language and grade selection. Their progress is discarded.

Bug 3: setLocale() Is Async, Not Awaited — Race Condition
File: lib/features/auth/presentation/onboarding_screen.dart, lines 427-443

onTap: () {
    ref.read(localeProvider.notifier).setLocale('en');  // ← async, not awaited!
    _nextStep();                                         // ← runs BEFORE setLocale completes
},
File: lib/core/localization/app_localizations.dart, lines 25-38

Future<void> setLocale(String languageCode) async {
    state = languageCode;                    // synchronous
    final profile = _authState.profile;
    if (profile != null) {
        profile.preferredLanguage = languageCode;
        await _ref.read(authProvider.notifier).updateProfile(profile);  // ← ASYNC, not awaited by caller
    }
}
Impact: If a profile exists, setLocale → updateProfile → authProvider state change → localeProvider is recreated (it watches authProvider) → OnboardingScreen rebuilds. This rebuild during the _pageController.nextPage() animation can cause:

The PageView widget tree to be rebuilt mid-animation
The localeProvider recreation to cause a fresh LocaleNotifier whose _initLocale() resets state
The router redirect (via GoRouter's reactive redirect) to fire and unmount the screen
This is the most likely cause of the "select a grade" bug the user describes: the setLocale async chain interferes with the PageView's nextPage() animation, so the page doesn't visually advance, yet _currentStep is incremented to 2 (making the progress indicator show 2 bars), and the rebuild from setLocale can cause the text to render incorrectly or the wrong page content to appear.

Bug 4: _startSimulatedDownload() Called Before Animation Completes
File: lib/features/auth/presentation/onboarding_screen.dart, lines 87-107

setState(() { _currentStep++; });          // _currentStep becomes 3

_pageController.nextPage(...).then((_) {   // animation starts
    _isAnimating = false;
});

if (_currentStep == 3) {                    // ← checked IMMEDIATELY (before animation)
    _startSimulatedDownload();              // ← fires while PageView is still animating
}
Impact: _startSimulatedDownload() does database writes, triggers sync, and eventually calls context.go('/student') — all while the PageView is mid-animation. This can cancel the animation, cause the widget to unmount mid-transition, and trigger _isAnimating flag issues.

Bug 5: PageController Never Disposed
File: lib/features/auth/presentation/onboarding_screen.dart, lines 41-44

@override
void dispose() {
    debugPrint('_OnboardingScreenState.dispose! hashCode=$hashCode');
    super.dispose();  // ← _pageController.dispose() is MISSING!
}
Impact: Resource leak. When the widget is unmounted (e.g., by a router redirect), the PageController is not disposed, which can cause errors if nextPage() or jumpToPage() is called on a detached controller.

Bug 6: Missing mounted Checks in _nextStep()
_nextStep() calls setState() and _pageController.nextPage() without checking mounted. If a router redirect (triggered by setLocale → updateProfile → authProvider change) unmounts the widget while _nextStep() is executing, setState() will throw a FlutterError.

Bug 7: Parent & Teacher Roles Require Authentication to Test
File: lib/features/auth/presentation/onboarding_screen.dart, lines 318-327

// Parent
onTap: () => context.go('/signup?role=parent'),  // ← navigates to signup form
// Teacher
onTap: () => context.go('/signup?role=teacher'), // ← navigates to signup form
The signup screen (signup_screen.dart) requires email/password input and calls auth.signUp(), which requires Supabase. There is no way to bypass authentication to test the Parent or Teacher dashboard UIs.

The Parent and Teacher dashboards exist as screens:

ParentDashboardScreen (wrapped in ParentShell) → route /parent
AdminDiagnosticsScreen (wrapped in AdminShell) → route /admin
But the router's Rule 2 prevents access without a profile with the correct role.

Plan
Phase 1: Fix Router Rules (Fixes Bug 1 & Bug 7)
File: lib/core/router/app_router.dart

Re-order rules: Move the incomplete-profile check (currently in Rule 3) to fire BEFORE Rule 2, or integrate it into Rule 2's logic for students specifically.
Guard profile! access: Add a null check before profile!.role to prevent NullPointerException when isSignedIn=true but hasProfile=false.
Add guest test mode: Add a query parameter (e.g., /onboarding?testRole=parent) or a debug flag that creates a mock profile with the specified role, allowing the router to navigate to that role's home screen without authentication.
Phase 2: Fix OnboardingScreen State Management (Fixes Bugs 2-6)
File: lib/features/auth/presentation/onboarding_screen.dart

PageController.dispose(): Add _pageController.dispose() to dispose().
_resumeFromExistingProfile(): Remove the if (isSignedIn) guard so guest profiles are also resumed from. For guests with a profile:
Language + grade set → _currentStep = 3
Language only → _currentStep = 2
No language → _currentStep = 1
No profile → _currentStep = 1 (skip welcome, go straight to language)
Await setLocale before _nextStep(): Change the language card onTap to:
onTap: () async {
    await ref.read(localeProvider.notifier).setLocale('am');
    if (!mounted) return;
    _nextStep();
},
Move _startSimulatedDownload() into the animation callback:
_pageController.nextPage(...).then((_) {
    _isAnimating = false;
    if (_currentStep == 3) {
        _startSimulatedDownload();
    }
});
Add mounted checks: Before setState and _pageController.nextPage() in _nextStep(), check if (!mounted) return;.
Remove _resumeFromExistingProfile() call from initState() and instead call it in the first build() or in an addPostFrameCallback, because authProvider might not have loaded the profile yet during initState() (it loads asynchronously).
Phase 3: Add Testing Infrastructure
Debug/test mode for all 3 roles: Add a mechanism (e.g., a query parameter testMode or a dev menu) that injects a mock authProvider with a pre-built ProfileLocal for the selected role (student/parent/teacher), bypassing signup entirely.
Expand widget tests: Extend test/onboarding_test.dart to:
Test the full student flow: tap Student → tap Language → tap Grade → verify pages change
Verify page content at each step (e.g., text "Select Your Language" on page 1, "Select Your Grade" on page 2)
Test guest resume (pre-populate a profile and verify _currentStep is correct)
Add tests for parent and teacher role cards navigating correctly
Add page verification to tests: Use find.text() or find.widget to assert which page is currently visible after each tap, ensuring no duplication or stale content.
Phase 4: Verify Page Transitions
For each transition, verify:

From	To	Trigger	Expected Page Content	Verification
Welcome (0)	Language (1)	Tap "Student" card	"Select Your Language" title	✅ Verify find.text('Select Your Language')
Language (1)	Grade (2)	Tap "English"/"Amharic" card	"Select Your Grade" title	✅ Verify find.text('Select Your Grade')
Grade (2)	Download (3)	Tap grade card (e.g., "9")	"Download Course Materials" title	✅ Verify selectDownloadResources text
Download (3)	Student Dashboard	After sync	Navigates to /student	✅ Verify route change
Key check for the "select a grade" bug: After tapping a language card, verify that _pageController.page equals 2 (or is animating toward 2), and that the visible text is "Select Your Grade" (from _buildGradeStep), NOT "Select Your Language" (from _buildLanguageStep). If the PageView doesn't advance, the _pageController.page would stay at 1 and the visible text would be "Select Your Language."

Phase 5: Testing Without Database/Auth
Since the goal is to test UI/design without real database/auth:

Mock isarProvider with a MockIsar (already used in existing tests)
Override authProvider with a custom AuthNotifier that has a pre-set guest profile
Override syncProvider to skip the network sync call
Add a test helper that creates a guest session with a specific role:
// Example test helper
void injectGuestSession(ProviderContainer container, {
    required String role,
    String language = 'en',
    int? grade,
}) {
    final profile = ProfileLocal()
      ..uuid = 'test-guest'
      ..role = role
      ..preferredLanguage = language
      ..selectedGradeLevel = grade
      ..isDirty = false
      ..updatedAt = DateTime.now();
    container.read(authProvider.notifier).setGuestSession(profile);
}
This allows testing:

Student UI: injectGuestSession(container, role: 'student', language: 'en', grade: 9) → navigate to /student
Parent UI: injectGuestSession(container, role: 'parent') → navigate to /parent → see ParentDashboardScreen
Teacher UI (admin): injectGuestSession(container, role: 'teacher') → navigate to /admin → see AdminDiagnosticsScreen