import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_model.dart';

abstract class IChatRemoteDataSource {
  Future<ChatModel> sendMessage(
    String text, {
    required List<Map<String, dynamic>> history,
    String? systemInstruction,
  });
}

class GeminiRemoteDataSource implements IChatRemoteDataSource {
  final List<String> _models = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-3.1-flash-lite-preview',
    'gemini-3-flash',
  ];

  GeminiRemoteDataSource() {
    if (dotenv.env['GEMINI_API_KEY'] == null ||
        dotenv.env['GEMINI_API_KEY']!.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }

  @override
  Future<ChatModel> sendMessage(
    String text, {
    required List<Map<String, dynamic>> history,
    String? systemInstruction,
  }) async {
    // Convert history to Content once
    final chatHistory = history.map((e) {
      if (e['is_user'] == true || e['is_user'] == 1) {
        return Content.text(e['content']);
      } else {
        return Content.model([TextPart(e['content'])]);
      }
    }).toList();

    for (int i = 0; i < _models.length; i++) {
      final modelName = _models[i];
      final model = GenerativeModel(
        model: modelName,
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        systemInstruction: systemInstruction != null
            ? Content.system(systemInstruction)
            : null,
      );

      final chatSession = model.startChat(history: chatHistory);

      try {
        if (kDebugMode) {
          print(
            '[GeminiDS] ➤ Model   : $modelName  (attempt ${i + 1}/${_models.length})',
          );
        }
        if (kDebugMode) {
          print('[GeminiDS] ➤ Message : $text');
        }
        final stopwatch = Stopwatch()..start();

        final response = await chatSession
            .sendMessage(Content.text(text))
            .timeout(const Duration(seconds: 35));

        stopwatch.stop();
        if (kDebugMode) {
          print('[GeminiDS] ✓ Latency : ${stopwatch.elapsedMilliseconds} ms');
        }

        if (response.text != null) {
          return ChatModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: response.text!,
            timestamp: DateTime.now(),
            isUser: false,
          );
        } else {
          throw Exception('Failed to get response from Gemini ($modelName)');
        }
      } catch (e) {
        final errorString = e.toString().toLowerCase();

        // The Gemini SDK sometimes returns quota errors as:
        //   "You exceeded your current quota..."  → no '429' in the string
        //   "resource_exhausted"                  → gRPC style
        //   "rate limit"                          → generic wording
        // So we check all known forms, not just the HTTP status code.
        final isRateLimit =
            errorString.contains('429') ||
            errorString.contains('quota') ||
            errorString.contains('resource_exhausted') ||
            errorString.contains('rate limit');

        final isTransient =
            isRateLimit ||
            errorString.contains('503') ||
            errorString.contains('502') ||
            errorString.contains('timeout') ||
            e is TimeoutException;

        final preview = e.toString();
        if (kDebugMode) {
          print(
            '[GeminiDS] ✗ Error on $modelName'
            ' | isRateLimit=$isRateLimit'
            ' | isTransient=$isTransient'
            ' | msg=${preview.substring(0, preview.length.clamp(0, 200))}',
          );
        }

        // If it's the last model or the error is non-transient (e.g. 400/404), give up.
        if (i == _models.length - 1 || !isTransient) {
          rethrow;
        }

        // Quota/rate-limit: window resets every 60 s — wait it out before next model.
        // Other transient errors (502/503/timeout): shorter exponential pause.
        final delaySeconds = isRateLimit ? 62 : (i + 1) * 3;
        if (kDebugMode) {
          print(
            '[GeminiDS] ↻ Waiting ${delaySeconds}s then trying ${_models[i + 1]}...',
          );
        }
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    throw Exception('Failed to send message after trying all models.');
  }
}
