import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_model.dart';

abstract class IChatRemoteDataSource {
  Future<ChatModel> sendMessage(String text);
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
  Future<ChatModel> sendMessage(String text) async {
    final content = [Content.text(text)];
    final response = await _model.generateContent(content);

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
