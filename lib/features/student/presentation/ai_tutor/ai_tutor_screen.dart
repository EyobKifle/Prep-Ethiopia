import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/theme/app_theme.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  final String? textbookUuid;
  final String? lessonUuid;

  const AiTutorScreen({super.key, this.textbookUuid, this.lessonUuid});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGenerating = false;
  bool _isModelLoaded = false;
  String? _loadingError;
  List<AiMessageLocal> _messages = [];
  String _currentResponse = "";

  @override
  void initState() {
    super.initState();
    _checkModelAndLoad();
  }

  Future<void> _checkModelAndLoad() async {
    final aiService = ref.read(aiServiceProvider);
    
    // In this implementation, we assume the model is downloaded to a specific path
    // For production, you'd check if it exists and offer to download it.
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/models/llama-3.2-1b-q4.gguf';
    
    if (await File(modelPath).exists()) {
      try {
        await aiService.initialize(modelPath);
        setState(() => _isModelLoaded = true);
      } catch (e) {
        setState(() => _loadingError = "Failed to load AI brain: $e");
      }
    } else {
      setState(() => _loadingError = "AI model not found. Please download it in settings.");
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isModelLoaded || _isGenerating) return;

    _messageController.clear();
    
    final userMessage = AiMessageLocal()
      ..uuid = DateTime.now().millisecondsSinceEpoch.toString()
      ..role = 'user'
      ..content = text
      ..createdAt = DateTime.now();

    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
      _currentResponse = "";
    });

    _scrollToBottom();

    final aiService = ref.read(aiServiceProvider);
    
    try {
      final responseStream = aiService.answerQuestion(text);
      
      responseStream.listen(
        (token) {
          setState(() {
            _currentResponse += token;
          });
          _scrollToBottom();
        },
        onDone: () {
          final assistantMessage = AiMessageLocal()
            ..uuid = (DateTime.now().millisecondsSinceEpoch + 1).toString()
            ..role = 'assistant'
            ..content = _currentResponse
            ..createdAt = DateTime.now();

          setState(() {
            _messages.add(assistantMessage);
            _currentResponse = "";
            _isGenerating = false;
          });
        },
        onError: (e) {
          setState(() {
            _loadingError = "Generation error: $e";
            _isGenerating = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _loadingError = "Error: $e";
        _isGenerating = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Study Buddy"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(() => _messages = []),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingError != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_loadingError!, style: const TextStyle(color: Colors.red))),
                  if (_loadingError!.contains("not found"))
                    TextButton(onPressed: () {}, child: const Text("Download")),
                ],
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isGenerating ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildMessageBubble("assistant", _currentResponse, true);
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg.role, msg.content, false);
              },
            ),
          ),
          
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String role, String content, bool isTyping) {
    final isUser = role == 'user';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser 
              ? (isDark ? Colors.blue[900] : Colors.blue[100])
              : (isDark ? Colors.grey[850] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.isEmpty && isTyping ? "Thinking..." : content,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: _isModelLoaded && !_isGenerating,
              decoration: InputDecoration(
                hintText: "Ask your study buddy...",
                border: OutlineInputBorder(borderRadius: AppTheme.borderRadius),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: (_isModelLoaded && !_isGenerating) ? _sendMessage : null,
            icon: _isGenerating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
