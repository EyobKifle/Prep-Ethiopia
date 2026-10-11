import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class TextbookViewerScreen extends ConsumerStatefulWidget {
  final String textbookUuid;
  const TextbookViewerScreen({super.key, required this.textbookUuid});

  @override
  ConsumerState<TextbookViewerScreen> createState() => _TextbookViewerScreenState();
}

class _TextbookViewerScreenState extends ConsumerState<TextbookViewerScreen> {
  TextbookLocal? _textbook;
  List<TextbookNoteLocal> _notes = [];
  List<TextbookHighlightLocal> _highlights = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _loadTextbook();
    _loadNotes();
    _loadHighlights();
  }

  Future<void> _loadTextbook() async {
    final isar = ref.read(isarProvider);
    final textbook = await isar.textbookLocals.where().uuidEqualTo(widget.textbookUuid).findFirst();
    
    if (mounted) {
      setState(() {
        _textbook = textbook;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotes() async {
    final isar = ref.read(isarProvider);
    final notes = await isar.textbookNoteLocals
        .where()
        .textbookUuidEqualTo(widget.textbookUuid)
        .findAll();
    
    if (mounted) {
      setState(() {
        _notes = notes;
      });
    }
  }

  Future<void> _loadHighlights() async {
    final isar = ref.read(isarProvider);
    final highlights = await isar.textbookHighlightLocals
        .where()
        .textbookUuidEqualTo(widget.textbookUuid)
        .findAll();
    
    if (mounted) {
      setState(() {
        _highlights = highlights;
      });
    }
  }

  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    if (details.selectedText != null) {
      // Automatically show a small snackbar or option to highlight
      _showHighlightOption(details.selectedText!);
    }
  }

  void _showHighlightOption(String text) {
     ScaffoldMessenger.of(context).hideCurrentSnackBar();
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Selected: ${text.length > 20 ? '${text.substring(0, 20)}...' : text}'),
         action: SnackBarAction(
           label: 'HIGHLIGHT',
           onPressed: () => _saveHighlight(text),
         ),
         duration: const Duration(seconds: 4),
       ),
     );
  }

  Future<void> _saveHighlight(String text) async {
    final isar = ref.read(isarProvider);
    final authState = ref.read(authProvider);
    final userId = authState.profile?.uuid ?? 'guest';

    final highlight = TextbookHighlightLocal()
      ..uuid = 'hl_${DateTime.now().millisecondsSinceEpoch}'
      ..textbookUuid = widget.textbookUuid
      ..userUuid = userId
      ..pageNumber = _currentPage
      ..selectedText = text
      ..colorHex = '0xFFFFEB3B'
      ..boundsJson = ''
      ..isDirty = true
      ..isDeleted = false
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.textbookHighlightLocals.put(highlight);
    });

    _pdfViewerController.clearSelection();
    _loadHighlights();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to highlights'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _createNote() async {
    final authState = ref.read(authProvider);
    final userId = authState.profile?.uuid ?? 'guest';

    final note = TextbookNoteLocal()
      ..uuid = 'note_${DateTime.now().millisecondsSinceEpoch}'
      ..textbookUuid = widget.textbookUuid
      ..userUuid = userId
      ..pageNumber = _currentPage
      ..dx = 0
      ..dy = 0
      ..content = ''
      ..isDirty = true
      ..isDeleted = false
      ..updatedAt = DateTime.now();

    _showNoteEditor(note);
  }

  void _showNoteEditor(TextbookNoteLocal note) {
    final controller = TextEditingController(text: note.content);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('Edit Note'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final content = controller.text.trim();
                if (content.isNotEmpty) {
                  note.content = content;
                  note.updatedAt = DateTime.now();
                  final isar = ref.read(isarProvider);
                  await isar.writeTxn(() async {
                    await isar.textbookNoteLocals.put(note);
                  });
                  _loadNotes();
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: controller,
            maxLines: 8,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type your notes here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNotesOverview() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DefaultTabController(
        length: 2,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(text: 'My Notes'),
                  Tab(text: 'Highlights'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildNotesList(),
                    _buildHighlightsList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    if (_notes.isEmpty) {
      return _buildEmptyState('No notes yet. Tap the + icon to add one.');
    }
    return ListView.builder(
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildListItem(
          icon: Icons.sticky_note_2_outlined,
          title: note.content?.isEmpty ?? true ? '(Empty Note)' : note.content!,
          subtitle: 'Page ${note.pageNumber}',
          onTap: () {
            Navigator.pop(context);
            _pdfViewerController.jumpToPage(note.pageNumber);
            _showNoteEditor(note);
          },
          onDelete: () async {
            final isar = ref.read(isarProvider);
            await isar.writeTxn(() async => await isar.textbookNoteLocals.delete(note.id));
            _loadNotes();
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildHighlightsList() {
    if (_highlights.isEmpty) {
      return _buildEmptyState('No highlights yet. Select text to highlight it.');
    }
    return ListView.builder(
      itemCount: _highlights.length,
      itemBuilder: (context, index) {
        final hl = _highlights[index];
        return _buildListItem(
          icon: Icons.colorize,
          title: hl.selectedText,
          subtitle: 'Page ${hl.pageNumber}',
          onTap: () {
            Navigator.pop(context);
            _pdfViewerController.jumpToPage(hl.pageNumber);
          },
          onDelete: () async {
            final isar = ref.read(isarProvider);
            await isar.writeTxn(() async => await isar.textbookHighlightLocals.delete(hl.id));
            _loadHighlights();
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_textbook == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('emptyStateTitle'))),
      );
    }

    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_textbook!.title.getLocalized(currentLocale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_alt_outlined),
            tooltip: 'View All Notes',
            onPressed: _showNotesOverview,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Add Note to Page',
            onPressed: _createNote,
          ),
        ],
      ),
      body: _buildPdfViewer(),
      bottomNavigationBar: _totalPages > 0 
          ? SafeArea(
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      '$_currentPage / $_totalPages',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: _currentPage.toDouble(),
                        min: 1,
                        max: _totalPages.toDouble(),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        onChanged: (val) {
                          _pdfViewerController.jumpToPage(val.toInt());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPdfViewer() {
    final bool useLocal = _textbook!.isDownloaded && _textbook!.localPdfPath != null;
    
    if (useLocal) {
      final file = File(_textbook!.localPdfPath!);
      if (file.existsSync()) {
        return SfPdfViewer.file(
          file,
          controller: _pdfViewerController,
          scrollDirection: PdfScrollDirection.vertical,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() {
              _totalPages = details.document.pages.count;
              _currentPage = 1;
            });
          },
          onPageChanged: (PdfPageChangedDetails details) {
            setState(() {
              _currentPage = details.newPageNumber;
            });
          },
          onTextSelectionChanged: _onTextSelectionChanged,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            _showErrorSnackBar('Failed to load local PDF: ${details.error}');
          },
        );
      }
    }

    return SfPdfViewer.network(
      _textbook!.pdfUrl,
      controller: _pdfViewerController,
      scrollDirection: PdfScrollDirection.vertical,
      pageLayoutMode: PdfPageLayoutMode.continuous,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _totalPages = details.document.pages.count;
          _currentPage = 1;
        });
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
      onTextSelectionChanged: _onTextSelectionChanged,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        _showErrorSnackBar('Failed to load PDF from network: ${details.error}');
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
