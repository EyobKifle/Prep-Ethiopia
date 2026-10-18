import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class WorksheetEditorScreen extends ConsumerStatefulWidget {
  final String worksheetUuid;
  const WorksheetEditorScreen({super.key, required this.worksheetUuid});

  @override
  ConsumerState<WorksheetEditorScreen> createState() => _WorksheetEditorScreenState();
}

class _WorksheetEditorScreenState extends ConsumerState<WorksheetEditorScreen> {
  WorksheetLocal? _worksheet;
  List<WorksheetQuestionLocal> _questions = [];
  bool _isLoading = true;
  double _uploadProgress = 0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadWorksheetData();
  }

  Future<void> _loadWorksheetData() async {
    setState(() => _isLoading = true);
    final isar = ref.read(isarProvider);
    
    final worksheet = await isar.worksheetLocals.where().uuidEqualTo(widget.worksheetUuid).findFirst();
    final questions = await isar.worksheetQuestionLocals
        .filter()
        .worksheetUuidEqualTo(widget.worksheetUuid)
        .isDeletedEqualTo(false)
        .sortBySequenceNumber()
        .findAll();

    if (mounted) {
      setState(() {
        _worksheet = worksheet;
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWorksheet() async {
    if (_worksheet == null) return;
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      _worksheet!.isDirty = true;
      _worksheet!.updatedAt = DateTime.now();
      await isar.worksheetLocals.put(_worksheet!);
      for (var q in _questions) {
        q.isDirty = true;
        q.updatedAt = DateTime.now();
        await isar.worksheetQuestionLocals.put(q);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worksheet saved and marked for sync')));
    }
  }

  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final filename = '${widget.worksheetUuid}.pdf';
      final api = ref.read(remoteApiServiceProvider);

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      try {
        final url = await api.uploadFile(
          bytes: bytes,
          bucket: 'worksheets',
          filename: filename,
          onSendProgress: (sent, total) {
            setState(() {
              _uploadProgress = sent / total;
            });
          },
        );

        _worksheet!.pdfUrl = {'en': url, 'am': url};
        _worksheet!.pdfSize = {'en': bytes.length, 'am': bytes.length};
        _worksheet!.updatedAt = DateTime.now();
        _worksheet!.isDirty = true;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Uploaded Successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _addQuestion() {
    final newQuestion = WorksheetQuestionLocal()
      ..uuid = 'ws_q_${DateTime.now().millisecondsSinceEpoch}'
      ..worksheetUuid = widget.worksheetUuid
      ..sequenceNumber = _questions.length + 1
      ..questionText = {'en': '', 'am': ''}
      ..options = ['', '', '', '']
      ..correctOptionIndex = 0
      ..explanation = {'en': '', 'am': ''}
      ..updatedAt = DateTime.now()
      ..isDirty = true;
    
    setState(() {
      _questions.add(newQuestion);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_worksheet == null) return const Scaffold(body: Center(child: Text('Worksheet not found')));

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Worksheet: ${_worksheet!.title.getLocalized(context.currentLocale)}'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveWorksheet),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildWorksheetGeneralInfo(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const Divider(),
            ...List.generate(_questions.length, (index) => _buildQuestionEditor(_questions[index], index)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorksheetGeneralInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Worksheet Title (EN)'),
              onChanged: (val) {
                final titles = Map<String, String>.from(_worksheet!.title);
                titles['en'] = val;
                _worksheet!.title = titles;
              },
              controller: TextEditingController(text: _worksheet!.title['en']),
            ),
            const SizedBox(height: 16),
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Uploading: ${(_uploadProgress * 100).toInt()}%'),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _pickAndUploadPdf,
                icon: const Icon(Icons.upload_file),
                label: Text(_worksheet!.pdfUrl.isEmpty ? 'Upload PDF Reference' : 'Replace PDF Reference'),
              ),
            if (_worksheet!.pdfUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Current PDF: ${_worksheet!.pdfUrl.values.first}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionEditor(WorksheetQuestionLocal question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question ${question.sequenceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              decoration: const InputDecoration(labelText: 'Question Text (EN)'),
              maxLines: 2,
              onChanged: (val) {
                final texts = Map<String, String>.from(question.questionText);
                texts['en'] = val;
                question.questionText = texts;
              },
              controller: TextEditingController(text: question.questionText['en']),
            ),
            const SizedBox(height: 16),
            const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
            ...List.generate(4, (optIndex) => TextField(
              decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + optIndex)}'),
              onChanged: (val) {
                final opts = List<String>.from(question.options);
                opts[optIndex] = val;
                question.options = opts;
              },
              controller: TextEditingController(text: question.options[optIndex]),
            )),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: question.correctOptionIndex,
              decoration: const InputDecoration(labelText: 'Correct Option'),
              items: List.generate(4, (i) => DropdownMenuItem(value: i, child: Text('Option ${String.fromCharCode(65 + i)}'))),
              onChanged: (val) => setState(() => question.correctOptionIndex = val ?? 0),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Explanation (EN)'),
              maxLines: 2,
              onChanged: (val) {
                final exps = Map<String, String>.from(question.explanation);
                exps['en'] = val;
                question.explanation = exps;
              },
              controller: TextEditingController(text: question.explanation['en']),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    final removed = _questions.removeAt(index);
                    _markQuestionDeleted(removed.uuid);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markQuestionDeleted(String uuid) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final q = await isar.worksheetQuestionLocals.where().uuidEqualTo(uuid).findFirst();
      if (q != null) {
        q.isDeleted = true;
        q.isDirty = true;
        q.updatedAt = DateTime.now();
        await isar.worksheetQuestionLocals.put(q);
      }
    });
  }
}
