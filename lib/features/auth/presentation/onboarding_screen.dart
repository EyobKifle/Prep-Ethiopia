import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../core/database/isar_models.dart';
import '../../../core/database/isar_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../sync/sync_service.dart';
import '../auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final String? testRole;
  const OnboardingScreen({super.key, this.testRole});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int? _selectedGrade;
  double _downloadProgress = 0.0;

  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    debugPrint('_OnboardingScreenState.initState! hashCode=$hashCode');
    _resumeFromExistingProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Handle test mode - bypass onboarding for testing role UIs without auth
      if (widget.testRole != null) {
        _initTestMode();
      }

      if (mounted) {
        debugPrint('addPostFrameCallback firing! _currentStep=$_currentStep');
        _pageController.jumpToPage(_currentStep);
      }
    });
  }

  void _initTestMode() {
    final profile = ProfileLocal()
      ..uuid = 'test_${widget.testRole}_${DateTime.now().millisecondsSinceEpoch}'
      ..role = widget.testRole!
      ..preferredLanguage = ref.read(localeProvider)
      ..selectedGradeLevel = 9
      ..isDirty = false
      ..updatedAt = DateTime.now();

    ref.read(authProvider.notifier).setGuestSession(profile);
  }

  @override
  void dispose() {
    debugPrint('_OnboardingScreenState.dispose! hashCode=$hashCode');
    _pageController.dispose();
    super.dispose();
  }

  void _resumeFromExistingProfile() {
    final profile = ref.read(authProvider).profile;
    if (profile == null) {
      return;
    }

    final hasLanguage = profile.preferredLanguage.isNotEmpty;
    final hasGrade = profile.selectedGradeLevel != null;

    if (hasGrade) {
      _selectedGrade = profile.selectedGradeLevel;
    }

    // Resume from the appropriate step based on profile completeness
    // (works for both signed-in and guest users)
    if (hasLanguage && hasGrade) {
      _currentStep = 3;
    } else if (hasLanguage) {
      _currentStep = 2;
    } else {
      _currentStep = 1;
    }
  }

  void _nextStep() {
    if (!mounted) return;
    debugPrint('_nextStep called! _isAnimating=$_isAnimating, _currentStep=$_currentStep');
    if (_isAnimating || _currentStep >= 3) {
      debugPrint('_nextStep BLOCKED by _isAnimating=$_isAnimating or _currentStep=$_currentStep');
      return;
    }

    // Enforce grade selection before entering the download step.
    if (_currentStep == 2 && _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pleaseSelectGrade'))),
      );
      return;
    }

    _isAnimating = true;
    setState(() {
      _currentStep++;
    });

    debugPrint('Calling _pageController.nextPage()... hasClients=${_pageController.hasClients}, positions=${_pageController.positions.length}, page=${_pageController.hasClients ? _pageController.page : null}');
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      debugPrint('_pageController.nextPage() completed! page=${_pageController.hasClients ? _pageController.page : null}');
      _isAnimating = false;
      if (_currentStep == 3) {
        _startSimulatedDownload();
      }
    }).catchError((e) {
      debugPrint('_pageController.nextPage() ERROR: $e');
      _isAnimating = false;
    });
  }

  void _previousStep() {
    if (_isAnimating || _currentStep <= 0) return;

    _isAnimating = true;
    setState(() {
      _currentStep--;
    });
    
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _isAnimating = false;
    });
  }

  void _startSimulatedDownload() async {
    // Hard guard: prevent writing a null grade into the profile.
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pleaseSelectGrade'))),
      );
      setState(() {
        _currentStep = 2;
      });
      _pageController.jumpToPage(2);
      return;
    }

    setState(() {
      _downloadProgress = 0.1; // Start progress
    });

    // 1. Save configuration to local database
    final isar = ref.read(isarProvider);
    final auth = ref.read(authProvider);
    final currentLang = ref.read(localeProvider);

    ProfileLocal? profile;

    // Create a local profile for the guest student if none exists
    if (auth.profile == null) {
      profile = ProfileLocal()
        ..uuid = 'guest_${DateTime.now().millisecondsSinceEpoch}'
        ..role = 'student'
        ..preferredLanguage = currentLang
        ..selectedGradeLevel = _selectedGrade!
        ..isDirty = false
        ..updatedAt = DateTime.now();
      
      await isar.writeTxn(() async {
        await isar.profileLocals.put(profile!);
      });
      ref.read(authProvider.notifier).setGuestSession(profile);
    } else {
      profile = auth.profile;
      await isar.writeTxn(() async {
        final profileUuid = auth.user?.id ?? auth.profile?.uuid;
        if (profileUuid != null) {
          final p = await isar.profileLocals.filter().uuidEqualTo(profileUuid).findFirst();
          if (p != null) {
            p.preferredLanguage = currentLang;
            p.selectedGradeLevel = _selectedGrade;
            p.updatedAt = DateTime.now();
            p.isDirty = auth.user != null;
            await isar.profileLocals.put(p);
            profile = p;
            
            if (auth.user == null) {
               ref.read(authProvider.notifier).setGuestSession(p);
            }
          }
        }
      });
    }

    setState(() {
      _downloadProgress = 0.3;
    });

    // 2. Trigger Real Sync for the curriculum metadata
    try {
      final syncNotifier = ref.read(syncProvider.notifier);
      await syncNotifier.triggerSync();
      
      setState(() {
        _downloadProgress = 1.0;
      });
    } catch (e) {
      // Even if sync fails, we can proceed to the dashboard where sync will retry
      debugPrint('Initial sync failed: $e');
      setState(() {
        _downloadProgress = 1.0;
      });
    }

    if (mounted) {
      context.go('/student');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Indicator (only show for student path after welcome)
            if (_currentStep > 0)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: List.generate(3, (index) {
                    final active = index <= (_currentStep - 1);
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.grey[800] : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(context),
                  _buildLanguageStep(context),
                  _buildGradeStep(context),
                  _buildDownloadStep(context),
                ],
              ),
            ),

            // Navigation Bottom Bar
            if (_currentStep > 0 && _currentStep < 3)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(context.tr('back')),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const SizedBox(height: 24),
          Text(
            'Prep Ethiopia',
            style: AppTheme.getHeadingStyle(context: context, fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('tagline'),
            style: AppTheme.getBodyStyle(context: context, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Text(
            context.tr('selectRole'),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          _buildRoleCard(
            context: context,
            title: context.tr('roleStudent'),
            subtitle: context.tr('studentSubtitle'),
            icon: Icons.school_outlined,
            onTap: _nextStep,
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            context: context,
            title: context.tr('roleParent'),
            subtitle: context.tr('parentSubtitle'),
            icon: Icons.family_restroom_outlined,
            onTap: () => context.go('/signup?role=parent'),
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            context: context,
            title: context.tr('roleTeacher'),
            subtitle: context.tr('teacherSubtitle'),
            icon: Icons.person_outline,
            onTap: () => context.go('/signup?role=teacher'),
          ),
          
          const Spacer(),
          
          OutlinedButton(
            onPressed: () => context.go('/login'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(context.tr('alreadyHaveAccount')),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1.0,
          ),
          borderRadius: AppTheme.borderRadius,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.getBodyStyle(context: context, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageStep(BuildContext context) {
    final currentLang = ref.watch(localeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('selectLanguage'),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('selectLanguageSubtitle'),
            style: AppTheme.getBodyStyle(context: context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Amharic Option
          _buildLanguageCard(
            context: context,
            title: 'አማርኛ (Amharic)',
            subtitle: 'በአማርኛ ቋንቋ ይማሩ',
            isSelected: currentLang == 'am',
            onTap: () async {
              await ref.read(localeProvider.notifier).setLocale('am');
              if (!mounted) return;
              _nextStep();
            },
          ),
          const SizedBox(height: 16),

          // English Option
          _buildLanguageCard(
            context: context,
            title: 'English',
            subtitle: 'Learn in English language',
            isSelected: currentLang == 'en',
            onTap: () async {
              await ref.read(localeProvider.notifier).setLocale('en');
              if (!mounted) return;
              _nextStep();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: AppTheme.borderRadius,
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.getBodyStyle(context: context, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('selectGrade'),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('selectGradeSubtitle'),
            style: AppTheme.getBodyStyle(context: context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: 6, // Grades 7 to 12
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
              ),
              itemBuilder: (context, index) {
                final gradeLevel = index + 7;
                final isSelected = _selectedGrade == gradeLevel;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedGrade = gradeLevel;
                    });
                    _nextStep();
                  },
                  borderRadius: AppTheme.borderRadius,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      borderRadius: AppTheme.borderRadius,
                      color: isSelected
                          ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02))
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$gradeLevel',
                          style: AppTheme.getHeadingStyle(context: context, fontSize: 32),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('appName'), // Simple localized tag placeholder
                          style: AppTheme.getBodyStyle(context: context, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_download_outlined,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('downloadResources'),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('downloadSubtitle'),
            style: AppTheme.getBodyStyle(context: context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 8,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_downloadProgress * 100).toInt()}%',
            style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
