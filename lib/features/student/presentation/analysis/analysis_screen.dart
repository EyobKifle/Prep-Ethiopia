import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../sync/sync_service.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  int _streakDays = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  Future<void> _loadAnalysisData() async {
    final isar = ref.read(isarProvider);
    _streakDays = await _calculateStreak(isar);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _calculateStreak(Isar isar) async {
    final allProgress = await isar.userProgressLocals
        .filter()
        .isCompletedEqualTo(true)
        .completedAtIsNotNull()
        .sortByCompletedAtDesc()
        .findAll();

    if (allProgress.isEmpty) return 0;

    final completedDays = allProgress
        .where((p) => p.completedAt != null)
        .map((p) {
          final d = p.completedAt!.toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (completedDays.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final mostRecent = completedDays.first;
    if (mostRecent.isBefore(todayDate.subtract(const Duration(days: 1)))) return 0;

    int streak = 1;
    for (int i = 1; i < completedDays.length; i++) {
      final expected = completedDays[i - 1].subtract(const Duration(days: 1));
      if (completedDays[i] == expected) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    // final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: const CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('navAnalysis')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('navAnalysis'),
              style: AppTheme.getHeadingStyle(context: context, fontSize: 24),
            ),
            const SizedBox(height: 24),
            
            // Streak Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadius,
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 48),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_streakDays Days',
                        style: AppTheme.getHeadingStyle(context: context, fontSize: 32),
                      ),
                      Text(
                        'Current Learning Streak',
                        style: AppTheme.getBodyStyle(context: context, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sync Status Card
            _buildSyncStatusCard(context, syncState),
            
            const SizedBox(height: 32),
            Text(
              'Subject Mastery',
              style: AppTheme.getHeadingStyle(context: context, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('Performance charts coming soon...'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pendingCount = syncState.pendingItemsCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.0,
        ),
        borderRadius: AppTheme.borderRadius,
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pendingCount > 0 ? Icons.sync_problem : Icons.sync,
                color: pendingCount > 0 ? AppTheme.pendingAmber : AppTheme.successGreen,
              ),
              const SizedBox(width: 12),
              Text(
                pendingCount > 0 ? 'Pending Sync' : 'All Data Synced',
                style: AppTheme.getHeadingStyle(context: context, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pendingCount > 0 
              ? 'You have $pendingCount updates to sync with the server.' 
              : 'Your progress is backed up and up-to-date.',
            style: AppTheme.getBodyStyle(context: context, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(syncProvider.notifier).triggerSync(),
              icon: const Icon(Icons.sync),
              label: Text(context.tr('syncNow')),
            ),
          ),
        ],
      ),
    );
  }
}
