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
  final GenerativeModel _model;

  GeminiRemoteDataSource()
    : _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      ) {
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
    // Recreate model if system instruction is provided or we need to apply it per request dynamically
    final model = systemInstruction != null
        ? GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
            systemInstruction: Content.system(systemInstruction),
          )
        : _model;

    // Convert history to Content
    final chatHistory = history.map((e) {
      if (e['is_user'] == true || e['is_user'] == 1) {
        return Content.text(e['content']);
      } else {
        return Content.model([TextPart(e['content'])]);
      }
    }).toList();

    // We can use startChat, or just append the user message to history
    final chatSession = model.startChat(history: chatHistory);
    final response = await chatSession.sendMessage(Content.text(text));

    if (response.text != null) {
      return ChatModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response.text!,
        timestamp: DateTime.now(),
        isUser: false,
      );
    } else {
      throw Exception('Failed to get response from Gemini');
    }
  }
}
