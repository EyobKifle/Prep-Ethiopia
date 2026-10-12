import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import '../../../../core/theme/app_theme.dart';

class AiTutorScreen extends ConsumerStatefulWidget {
  final String? textbookUuid;
  final String? lessonUuid;

  const AiTutorScreen({super.key, this.textbookUuid, this.lessonUuid});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Study Buddy"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 80,
                color: isDark ? Colors.blue[300] : Colors.blue[600],
              ),
              const SizedBox(height: 24),
              Text(
                "AI Tutor Unavailable",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "The offline AI tutor feature is currently disabled.\n\n"
                "This feature requires local LLM inference (llama.cpp) and vector search "
                "which are not available in this build.\n\n"
                "Future versions may include:\n"
                "• Cloud-based AI tutor via Supabase Edge Functions\n"
                "• Offline AI with optimized models\n"
                "• Textbook-aware Q&A using RAG",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back to Study"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}