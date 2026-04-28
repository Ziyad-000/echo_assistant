import 'dart:async';
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
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
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
        final response = await chatSession
            .sendMessage(Content.text(text))
            .timeout(const Duration(seconds: 35));

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
        final isTransient =
            errorString.contains('429') ||
            errorString.contains('503') ||
            errorString.contains('502') ||
            errorString.contains('timeout') ||
            e is TimeoutException;

        // If it's the last model or the error is not transient, throw
        if (i == _models.length - 1 || !isTransient) {
          rethrow;
        }

        // Exponential Backoff: Wait before switching to the next model
        // More delay for each subsequent model
        await Future.delayed(Duration(seconds: (i + 1) * 2));
        continue; // Try next model
      }
    }

    throw Exception('Failed to send message after trying all models.');
  }
}
