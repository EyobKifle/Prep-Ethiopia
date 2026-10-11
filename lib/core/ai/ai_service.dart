import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

class AiService {
  LlamaParent? _llamaParent;
  bool _isInitialized = false;
  String? _modelPath;

  bool get isInitialized => _isInitialized;

  Future<void> initialize(String modelPath) async {
    if (_isInitialized && _modelPath == modelPath) return;

    final file = File(modelPath);
    if (!await file.exists()) {
      throw Exception("Model file not found at $modelPath");
    }

    _modelPath = modelPath;

    // Initialize llama.cpp via IsolateParent for non-blocking Flutter usage
    final contextParams = ContextParams();
    contextParams.nCtx = 2048; // Sets the context size to 2048 tokens
    
    final modelParams = ModelParams();
    final samplingParams = SamplerParams();
    
    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: modelParams,
      contextParams: contextParams,
      samplingParams: samplingParams,
    );

    // Using LlamaParent to run inference in a separate isolate
    _llamaParent = LlamaParent(loadCommand, AlpacaFormat());
    await _llamaParent!.init();
    
    _isInitialized = true;
  }

  Stream<String> answerQuestion(String question, {String? context}) async* {
    if (!_isInitialized || _llamaParent == null) {
      throw Exception("AI Service not initialized");
    }

    final prompt = _buildPrompt(question, context);
    
    // Send prompt and yield tokens from the broadcast stream
    await _llamaParent!.sendPrompt(prompt);
    
    // We listen to the parent's stream which broadcasts tokens from the isolate
    yield* _llamaParent!.stream;
  }

  String _buildPrompt(String question, String? context) {
    if (context != null && context.isNotEmpty) {
      return """
You are a helpful study tutor for students in Ethiopia. 
Answer the following question based ONLY on the provided textbook context. 
If the answer is not in the context, say you don't know based on the textbook.

Context:
$context

Question:
$question

Answer:""";
    } else {
      return """
You are a helpful study tutor for students in Ethiopia. 
Answer the following question clearly and concisely.

Question:
$question

Answer:""";
    }
  }

  void dispose() {
    _llamaParent?.dispose();
    _isInitialized = false;
  }
}
