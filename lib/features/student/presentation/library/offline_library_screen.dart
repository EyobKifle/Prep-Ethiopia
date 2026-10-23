import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class OfflineLibraryScreen extends ConsumerStatefulWidget {
  const OfflineLibraryScreen({super.key});

  @override
  ConsumerState<OfflineLibraryScreen> createState() => _OfflineLibraryScreenState();
}

class _OfflineLibraryScreenState extends ConsumerState<OfflineLibraryScreen> {
  List<TextbookLocal> _downloadedTextbooks = [];
  List<UnitLocal> _downloadedUnits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarProvider);
    final auth = ref.read(authProvider);
    final gradeLevel = auth.profile?.selectedGradeLevel;
    
    List<TextbookLocal> textbooks;
    List<UnitLocal> units;

    if (gradeLevel != null) {
      final grade = await isar.gradeLocals.filter().levelEqualTo(gradeLevel).findFirst();
      if (grade != null) {
        final subjects = await isar.subjectLocals.filter().gradeUuidEqualTo(grade.uuid).findAll();
        final subjectUuids = subjects.map((s) => s.uuid).toList();
        if (subjectUuids.isNotEmpty) {
          textbooks = await isar.textbookLocals
              .filter()
              .isDownloadedEqualTo(true)
              .anyOf(subjectUuids, (q, String uuid) => q.subjectUuidEqualTo(uuid))
              .findAll();
          units = await isar.unitLocals
              .filter()
              .isDownloadedEqualTo(true)
              .anyOf(subjectUuids, (q, String uuid) => q.subjectUuidEqualTo(uuid))
              .findAll();
        } else {
          textbooks = [];
          units = [];
        }
      } else {
        textbooks = [];
        units = [];
      }
    } else {
      textbooks = await isar.textbookLocals.filter().isDownloadedEqualTo(true).findAll();
      units = await isar.unitLocals.filter().isDownloadedEqualTo(true).findAll();
    }

    if (mounted) {
      setState(() {
        _downloadedTextbooks = textbooks;
        _downloadedUnits = units;
        _isLoading = false;
      });
    }
  }

  double _calculateTotalSizeMB() {
    int totalBytes = 0;
    for (var t in _downloadedTextbooks) {
      if (t.localPdfPath != null) {
        if (t.localPdfPath!.startsWith('assets/')) {
          totalBytes += (t.pdfSizeBytes ?? 20000000);
        } else {
          final file = File(t.localPdfPath!);
          if (file.existsSync()) totalBytes += file.lengthSync();
        }
      }
    }
    for (var u in _downloadedUnits) {
      if (u.localPdfPath != null) {
        if (u.localPdfPath!.startsWith('assets/')) {
          totalBytes += 10000000;
        } else {
          final file = File(u.localPdfPath!);
          if (file.existsSync()) totalBytes += file.lengthSync();
        }
      }
    }
    return totalBytes / (1024 * 1024);
  }

  String _getFileSizeString(String? path, [int? bytesSize]) {
    if (path == null) return '0.0 MB';
    if (path.startsWith('assets/')) {
      if (bytesSize != null) {
        return '${(bytesSize / (1024 * 1024)).toStringAsFixed(1)} MB (Offline)';
      }
      return 'Offline';
    }
    final file = File(path);
    if (!file.existsSync()) return '0.0 MB';
    final bytes = file.lengthSync();
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _deleteTextbook(TextbookLocal textbook) async {
    if (textbook.localPdfPath?.startsWith('assets/') ?? false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official curriculum textbooks are permanently available offline.')),
        );
      }
      return;
    }

    final confirmed = await _showDeleteConfirmation(textbook.title.getLocalized(context.currentLocale));

    if (confirmed == true) {
      if (textbook.localPdfPath != null) {
        final file = File(textbook.localPdfPath!);
        if (file.existsSync()) file.deleteSync();
      }

      final isar = ref.read(isarProvider);
      textbook.isDownloaded = false;
      textbook.localPdfPath = null;
      textbook.updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.textbookLocals.put(textbook);
      });
      _loadData();
    }
  }

  Future<void> _deleteUnit(UnitLocal unit) async {
    final confirmed = await _showDeleteConfirmation(unit.title.getLocalized(context.currentLocale));

    if (confirmed == true) {
      if (unit.localPdfPath != null) {
        final file = File(unit.localPdfPath!);
        if (file.existsSync()) file.deleteSync();
      }

      final isar = ref.read(isarProvider);
      unit.isDownloaded = false;
      unit.localPdfPath = null;
      unit.updatedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.unitLocals.put(unit);
      });
      _loadData();
    }
  }

  Future<bool?> _showDeleteConfirmation(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to remove "$title" from your offline library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalSize = _calculateTotalSizeMB();
    const double limit = 2048; // 2 GB limit

    final authState = ref.watch(authProvider);
    final isGuest = authState.user == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('navLibrary')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/student/search'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!isGuest)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Storage Usage',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${totalSize.toStringAsFixed(1)} / $limit MB',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalSize / limit,
                        minHeight: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Using ${totalSize.toStringAsFixed(1)} MB of estimated 2 GB space',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          if (_downloadedTextbooks.isEmpty && _downloadedUnits.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Icon(Icons.library_books_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No offline content found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          else ...[
            if (_downloadedTextbooks.isNotEmpty) ...[
              Text(
                'Textbooks',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._downloadedTextbooks.map((t) => _buildItemTile(
                    t.title.getLocalized(context.currentLocale),
                    t.localPdfPath,
                    t.pdfSizeBytes,
                    () => _deleteTextbook(t),
                    () => context.push('/student/textbook/${t.uuid}'),
                  )),
              const SizedBox(height: 24),
            ],
            if (_downloadedUnits.isNotEmpty) ...[
              Text(
                'Course Units',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._downloadedUnits.map((u) => _buildItemTile(
                    u.title.getLocalized(context.currentLocale),
                    u.localPdfPath,
                    null,
                    () => _deleteUnit(u),
                    null,
                  )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildItemTile(String title, String? path, int? bytesSize, VoidCallback onDelete, VoidCallback? onOpen) {
    final isAsset = path?.startsWith('assets/') ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(_getFileSizeString(path, bytesSize), style: const TextStyle(fontSize: 12)),
        trailing: isAsset
            ? const Tooltip(
                message: 'Permanently offline',
                child: Icon(Icons.offline_pin, color: Colors.green),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: onDelete,
              ),
      ),
    );
  }
}
