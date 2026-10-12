import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class AdminDiagnosticsScreen extends ConsumerStatefulWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  ConsumerState<AdminDiagnosticsScreen> createState() => _AdminDiagnosticsScreenState();
}

class _AdminDiagnosticsScreenState extends ConsumerState<AdminDiagnosticsScreen> {
  List<AppDiagnosticsLogLocal> _logs = [];
  List<FeatureFlagLocal> _flags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);
    
    final logs = await isar.appDiagnosticsLogLocals.where().sortByCreatedAtDesc().limit(50).findAll();
    final flags = await isar.featureFlagLocals.where().findAll();

    if (mounted) {
      setState(() {
        _logs = logs;
        _flags = flags;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: const CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('adminDashboard')),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Feature Flags'),
              Tab(text: 'System Logs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFeatureFlagsTab(),
            _buildLogsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadDiagnostics,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget _buildFeatureFlagsTab() {
    if (_flags.isEmpty) {
      return const Center(child: Text('No feature flags found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _flags.length,
      itemBuilder: (context, index) {
        final flag = _flags[index];
        return Card(
          child: SwitchListTile(
            title: Text(flag.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(flag.description),
            value: flag.isEnabled,
            onChanged: (val) async {
              final isar = ref.read(isarProvider);
              flag.isEnabled = val;
              flag.updatedAt = DateTime.now();
              await isar.writeTxn(() => isar.featureFlagLocals.put(flag));
              _loadDiagnostics();
            },
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return const Center(child: Text('No diagnostics logs yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        Color levelColor = Colors.blue;
        if (log.logLevel == 'ERROR') levelColor = Colors.red;
        if (log.logLevel == 'WARNING') levelColor = Colors.orange;

        return Card(
          child: ExpansionTile(
            leading: Icon(Icons.bug_report, color: levelColor),
            title: Text(log.message, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${log.logLevel} • ${log.createdAt.toLocal()}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(log.stackTrace ?? 'No stack trace provided.', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    const SizedBox(height: 16),
                    const Text('Device Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(log.deviceInfoJson, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
