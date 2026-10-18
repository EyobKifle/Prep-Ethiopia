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
  final bool guestMode;
  const OnboardingScreen({super.key, this.testRole, this.guestMode = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int? _selectedGrade;
  double _downloadProgress = 0.0;

  bool _isAnimating = false;
  bool _isChoosingLanguage = false;
  bool _isSettingUp = false;
  bool _setupFailed = false;
  ProfileLocal? _pendingProfile;

  @override
  void initState() {
    super.initState();
    debugPrint('_OnboardingScreenState.initState! hashCode=$hashCode');
    if (widget.guestMode) {
      _currentStep = 1;
    } else {
      _resumeFromExistingProfile();
    }
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

  int get _visibleStep {
    if (!_pageController.hasClients) return _currentStep;
    return _pageController.page?.round() ?? _currentStep;
  }

  Future<void> _chooseLanguage(String languageCode) async {
    if (_isChoosingLanguage || _isAnimating) return;
    setState(() => _isChoosingLanguage = true);
    try {
      await ref.read(localeProvider.notifier).setLocale(languageCode);
    } catch (e) {
      debugPrint('Could not persist language preference: $e');
    }
    if (!mounted) return;
    setState(() => _isChoosingLanguage = false);
    _nextStep();
  }

  Future<void> _continueToDashboard() async {
    final profile = _pendingProfile;
    final auth = ref.read(authProvider);
    if (profile != null) {
      if (auth.user == null) {
        ref.read(authProvider.notifier).setGuestSession(profile);
      } else {
        await ref.read(authProvider.notifier).updateProfile(profile);
      }
    }
    if (mounted) context.go('/student');
  }

  void _nextStep() {
    if (!mounted) return;
    final visibleStep = _visibleStep;
    debugPrint('_nextStep called! _isAnimating=$_isAnimating, visibleStep=$visibleStep');
    if (_isAnimating || visibleStep >= 3) return;

    // Only require a grade when the visible page is the grade picker.
    if (visibleStep == 2 && _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pleaseSelectGrade'))),
      );
      return;
    }

    final nextStep = visibleStep + 1;
    _isAnimating = true;
    _pageController.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      if (!mounted) return;
      _isAnimating = false;
      if (nextStep == 3) {
        _startSimulatedDownload();
      }
    }).catchError((e) {
      debugPrint('_pageController.animateToPage() ERROR: $e');
      _isAnimating = false;
    });
  }

  void _previousStep() {
    final visibleStep = _visibleStep;
    if (_isAnimating || visibleStep <= 0) return;

    _isAnimating = true;
    _pageController.animateToPage(
      visibleStep - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _isAnimating = false;
    });
  }

  Future<void> _startSimulatedDownload() async {
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pleaseSelectGrade'))),
      );
      setState(() => _currentStep = 2);
      _pageController.jumpToPage(2);
      return;
    }

    setState(() {
      _isSettingUp = true;
      _setupFailed = false;
      _downloadProgress = 0.1;
    });

    final isar = ref.read(isarProvider);
    final auth = ref.read(authProvider);
    final currentLang = ref.read(localeProvider);
    late ProfileLocal profile;

    if (auth.profile == null) {
      profile = ProfileLocal()
        ..uuid = auth.user?.id ?? 'guest_' + DateTime.now().millisecondsSinceEpoch.toString()
        ..role = 'student'
        ..preferredLanguage = currentLang
        ..selectedGradeLevel = _selectedGrade
        ..isDirty = auth.user != null
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.profileLocals.put(profile);
      });
    } else {
      final currentProfile = auth.profile!;
      final profileUuid = auth.user?.id ?? currentProfile.uuid;
      await isar.writeTxn(() async {
        final localProfile = await isar.profileLocals
                .filter()
                .uuidEqualTo(profileUuid)
                .findFirst() ??
            currentProfile;
        localProfile.preferredLanguage = currentLang;
        localProfile.selectedGradeLevel = _selectedGrade;
        localProfile.updatedAt = DateTime.now();
        localProfile.isDirty = auth.user != null;
        await isar.profileLocals.put(localProfile);
        profile = localProfile;
      });
    }
    _pendingProfile = profile;

    if (!mounted) return;
    setState(() => _downloadProgress = 0.3);

    try {
      await ref.read(syncProvider.notifier).triggerSync();
      if (auth.user != null &&
          ref.read(syncProvider).status == SyncStatus.error) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = 1.0;
          _isSettingUp = false;
          _setupFailed = true;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _downloadProgress = 1.0;
        _isSettingUp = false;
      });
      await _continueToDashboard();
    } catch (e) {
      debugPrint('Initial sync failed: $e');
      if (!mounted) return;
      setState(() {
        _downloadProgress = 1.0;
        _isSettingUp = false;
        _setupFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (widget.guestMode ||
          _currentStep != 0 ||
          _isAnimating ||
          previous?.profile != null ||
          next.profile == null ||
          !mounted) {
        return;
      }

      _resumeFromExistingProfile();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentStep);
        }
      });
    });

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
                  children: [
                    context.tr('stepLanguage'),
                    context.tr('stepGrade'),
                    context.tr('stepReady'),
                  ].asMap().entries.map((entry) {
                    final index = entry.key;
                    final active = index <= (_currentStep - 1);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: active
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? Colors.grey[800] : Colors.grey[300]),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.value,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: active
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  if (_currentStep != page) {
                    setState(() => _currentStep = page);
                  }
                },
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
            if (_currentStep > 0)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _isSettingUp ? null : _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(context.tr('back')),
                    ),
                    const Spacer(),
                    if (_currentStep == 2)
                      FilledButton(
                        onPressed: _selectedGrade == null || _isAnimating
                            ? null
                            : _nextStep,
                        child: Text(context.tr('continue')),
                      ),
                    if (_currentStep == 3 && _setupFailed)
                      FilledButton(
                        onPressed: _continueToDashboard,
                        child: Text(context.tr('continueToDashboard')),
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
            onTap: _isChoosingLanguage ? null : () => _chooseLanguage('am'),
          ),
          const SizedBox(height: 16),

          // English Option
          _buildLanguageCard(
            context: context,
            title: 'English',
            subtitle: 'Learn in English language',
            isSelected: currentLang == 'en',
            onTap: _isChoosingLanguage ? null : () => _chooseLanguage('en'),
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
    required VoidCallback? onTap,
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
    final currentLang = ref.watch(localeProvider);
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
          const SizedBox(height: 12),
          Chip(
            avatar: const Icon(Icons.translate, size: 18),
            label: Text(context.tr(
              'selectedLanguage',
              arg: context.tr(currentLang == 'am' ? 'languageAmharic' : 'languageEnglish'),
            )),
          ),
          const SizedBox(height: 20),
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
            context.tr('setupTitle'),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('setupDashboard', arg: (_selectedGrade ?? '').toString()),
            style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _setupFailed
                ? context.tr('offlineSetupFailed')
                : context.tr('setupDashboardSubtitle'),
            style: AppTheme.getBodyStyle(context: context),
            textAlign: TextAlign.center,
          ),
          if (ref.watch(authProvider).user == null) ...[
            const SizedBox(height: 16),
            Text(
              context.tr('guestLocalSaveNotice'),
              style: AppTheme.getBodyStyle(context: context),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
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
          if (_isSettingUp)
            Text(
              ((_downloadProgress * 100).toInt()).toString() + '%',
              style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
            ),
          if (_setupFailed)
            Text(
              context.tr('offlineReady'),
              style: AppTheme.getBodyStyle(context: context),
            ),
        ],
      ),
    );
  }
}
