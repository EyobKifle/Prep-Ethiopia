import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class WorksheetListScreen extends ConsumerStatefulWidget {
  const WorksheetListScreen({super.key});

  @override
  ConsumerState<WorksheetListScreen> createState() => _WorksheetListScreenState();
}

class _WorksheetListScreenState extends ConsumerState<WorksheetListScreen> {
  List<UnitLocal> _units = [];
  Map<String, List<WorksheetLocal>> _worksheetsByUnit = {};
  Set<String> _completedWorksheetUuids = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarProvider);
    
    final worksheets = await isar.worksheetLocals.where().findAll();
    final attempts = await isar.worksheetAttemptLocals.where().findAll();
    final units = await isar.unitLocals.where().sortBySequenceNumber().findAll();

    final Map<String, List<WorksheetLocal>> grouped = {};
    for (var ws in worksheets) {
      grouped.putIfAbsent(ws.unitUuid, () => []).add(ws);
    }

    final completed = attempts.map((a) => a.worksheetUuid).toSet();

    if (mounted) {
      setState(() {
        // Only show units that have worksheets
        _units = units.where((u) => grouped.containsKey(u.uuid)).toList();
        _worksheetsByUnit = grouped;
        _completedWorksheetUuids = completed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: const CircularProgressIndicator()));
    }

    if (_units.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('worksheets'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                context.tr('noWorksheets'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('worksheets')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _units.length,
        itemBuilder: (context, index) {
          final unit = _units[index];
          final worksheets = _worksheetsByUnit[unit.uuid] ?? [];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                child: Text(
                  unit.title.getLocalized(context.currentLocale),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              ...worksheets.map((ws) {
                final isCompleted = _completedWorksheetUuids.contains(ws.uuid);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCompleted ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.assignment,
                        color: isCompleted ? Colors.green : Colors.blue,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      ws.title.getLocalized(context.currentLocale),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isCompleted ? 'Completed' : 'Available',
                      style: TextStyle(
                        color: isCompleted ? Colors.green.shade700 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/student/worksheet/${ws.uuid}'),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
