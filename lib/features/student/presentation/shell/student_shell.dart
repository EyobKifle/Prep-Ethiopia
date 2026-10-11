import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_provider.dart';
import '../../../sync/sync_service.dart';

class StudentShell extends ConsumerWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  int _getSelectedIndex(String location) {
    if (location.startsWith('/student/exercises') || location.startsWith('/student/worksheet')) {
      return 1;
    }
    if (location.startsWith('/student/library')) {
      return 2;
    }
    if (location.startsWith('/student/analysis')) {
      return 3;
    }
    if (location.startsWith('/student/profile')) {
      return 4;
    }
    if (location.startsWith('/student/ai-tutor')) {
      return 5;
    }
    return 0; // Default to Dashboard (Home)
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/student');
        break;
      case 1:
        context.go('/student/exercises');
        break;
      case 2:
        context.go('/student/library');
        break;
      case 3:
        context.go('/student/analysis');
        break;
      case 4:
        context.go('/student/profile');
        break;
      case 5:
        context.go('/student/ai-tutor');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(syncProvider);
    
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _getSelectedIndex(location);

    // Watch sync status
    final pendingCount = syncState.pendingItemsCount;

    final syncColor = pendingCount > 0 ? AppTheme.pendingAmber : AppTheme.successGreen;
    final syncTooltip = pendingCount > 0 
        ? context.tr('pendingSync', arg: '$pendingCount')
        : context.tr('synced');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          // -------------------------------------------------------------
          // DESKTOP LAYOUT (Navigation Sidebar)
          // -------------------------------------------------------------
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        width: 1.0,
                      ),
                    ),
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Card Header
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                              width: 1.0,
                            ),
                            borderRadius: AppTheme.borderRadius,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(

                                authState.profile?.fullName ?? authState.user?.id ?? 'Student',



                                style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                               Text(
                                 authState.profile?.selectedGradeLevel != null
                                     ? 'Grade ${authState.profile!.selectedGradeLevel}'
                                     : context.tr('gradeNotSet'),
                                 style: AppTheme.getBodyStyle(context: context, fontSize: 13),
                               ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Navigation Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildSidebarItem(
                              context: context,
                              icon: Icons.dashboard_outlined,
                              selectedIcon: Icons.dashboard,
                              label: context.tr('navHome'),
                              isSelected: selectedIndex == 0,
                              onTap: () => _onItemTapped(0, context),
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarItem(
                              context: context,
                              icon: Icons.assignment_outlined,
                              selectedIcon: Icons.assignment,
                              label: context.tr('navExercises'),
                              isSelected: selectedIndex == 1,
                              onTap: () => _onItemTapped(1, context),
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarItem(
                              context: context,
                              icon: Icons.cloud_download_outlined,
                              selectedIcon: Icons.cloud_download,
                              label: context.tr('navLibrary'),
                              isSelected: selectedIndex == 2,
                              onTap: () => _onItemTapped(2, context),
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarItem(
                              context: context,
                              icon: Icons.analytics_outlined,
                              selectedIcon: Icons.analytics,
                              label: context.tr('navAnalysis'),
                              isSelected: selectedIndex == 3,
                              onTap: () => _onItemTapped(3, context),
                            ),
                            const SizedBox(height: 8),
                            _buildSidebarItem(
                              context: context,
                              icon: Icons.person_outline,
                              selectedIcon: Icons.person,
                              label: context.tr('navProfile'),
                              isSelected: selectedIndex == 4,
                              onTap: () => _onItemTapped(4, context),
                            ),
                            const SizedBox(height: 8),
                             _buildSidebarItem(
                               context: context,
                               icon: Icons.psychology_outlined,
                               selectedIcon: Icons.psychology,
                               label: context.tr('navAiTutor'),
                               isSelected: selectedIndex == 5,
                               onTap: () => _onItemTapped(5, context),
                             ),
                          ],
                        ),
                      ),

                      // Footer Sync Info
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: syncColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                syncTooltip,
                                style: AppTheme.getBodyStyle(context: context, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sync, size: 16),
                              onPressed: () => ref.read(syncProvider.notifier).triggerSync(),
                              tooltip: context.tr('syncNow'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: child,
                ),
              ],
            ),
          );
        } else {
          // -------------------------------------------------------------
          // MOBILE LAYOUT (Appbar + BottomNavigationBar)
          // -------------------------------------------------------------
          return Scaffold(
            body: child,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    width: 1.0,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: selectedIndex,
                onTap: (index) => _onItemTapped(index, context),
                type: BottomNavigationBarType.fixed,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.dashboard_outlined),
                    activeIcon: const Icon(Icons.dashboard),
                    label: context.tr('navHome'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.assignment_outlined),
                    activeIcon: const Icon(Icons.assignment),
                    label: context.tr('navExercises'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.cloud_download_outlined),
                    activeIcon: const Icon(Icons.cloud_download),
                    label: context.tr('navLibrary'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.analytics_outlined),
                    activeIcon: const Icon(Icons.analytics),
                    label: context.tr('navAnalysis'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person_outline),
                    activeIcon: const Icon(Icons.person),
                    label: context.tr('navProfile'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.psychology_outlined),
                    activeIcon: const Icon(Icons.psychology),
                    label: context.tr('navAiTutor'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSidebarItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : Colors.transparent,
          border: Border.all(
            color: isSelected 
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            width: 1.0,
          ),
          borderRadius: AppTheme.borderRadius,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTheme.getHeadingStyle(
                  context: context,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
