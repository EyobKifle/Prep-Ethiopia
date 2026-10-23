import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_provider.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isGuest = authState.user == null;
    final profile = authState.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('navProfile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Header
          _buildUserHeader(context, profile, isGuest),
          const SizedBox(height: 24),

          if (isGuest) ...[
            _buildGuestPrompt(context),
            const SizedBox(height: 24),
          ],

          // Settings Section
          _buildSettingsSection(context, ref, profile),
          const SizedBox(height: 24),

          // Sign Out / Exit Guest Mode
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ref.read(authProvider.notifier).signOut();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: Text(isGuest ? 'Exit Guest Mode' : context.tr('signOut')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, profile, bool isGuest) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: AppTheme.lightBorder,
          child: Icon(Icons.person, size: 40, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Text(
          profile?.fullName ?? (isGuest ? 'Guest Student' : 'Student'),
          style: AppTheme.getHeadingStyle(context: context, fontSize: 20),
        ),
        if (profile?.selectedGradeLevel != null)
          Text(
            'Grade ${profile.selectedGradeLevel}',
            style: AppTheme.getBodyStyle(context: context),
          ),
      ],
    );
  }

  Widget _buildGuestPrompt(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  context.tr('guestMode'),
                  style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('guestProfileSyncMsg'),
              style: AppTheme.getBodyStyle(context: context),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/login'),
                    child: Text(context.tr('signIn')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/signup'),
                    child: Text(context.tr('createAccount')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, dynamic profile) {
    final currentLocale = context.currentLocale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.tr('languageSetting')),
                trailing: DropdownButton<String>(
                  value: currentLocale,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      ref.read(localeProvider.notifier).setLocale(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Grade Level'),
                subtitle: Text(
                  profile?.selectedGradeLevel != null
                      ? 'Grade ${profile!.selectedGradeLevel}'
                      : 'Not Selected',
                ),
                trailing: DropdownButton<int>(
                  value: profile?.selectedGradeLevel,
                  hint: const Text('Grade'),
                  underline: const SizedBox(),
                  onChanged: (int? newGrade) async {
                    if (newGrade != null && profile != null) {
                      profile.selectedGradeLevel = newGrade;
                      profile.updatedAt = DateTime.now();
                      await ref.read(authProvider.notifier).updateProfile(profile);
                    }
                  },
                  items: List.generate(12, (index) {
                    final grade = index + 1;
                    return DropdownMenuItem(
                      value: grade,
                      child: Text('Grade $grade'),
                    );
                  }),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(context.tr('themeSetting')),
                trailing: DropdownButton<ThemeMode>(
                  value: ref.watch(themeProvider),
                  underline: const SizedBox(),
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      ref.read(themeProvider.notifier).setThemeMode(newValue);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(context.tr('themeSystem')),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(context.tr('themeLight')),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(context.tr('themeDark')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
