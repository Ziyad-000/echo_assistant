import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_session.dart';

abstract class ChatState {
  final List<ChatSession> sessions;
  final String? currentChatId;
  final List<ChatMessage> messages;
  final bool isListening;
  final String? temporaryVoiceText;

  const ChatState({
    required this.sessions,
    this.currentChatId,
    required this.messages,
    this.isListening = false,
    this.temporaryVoiceText,
  });
}

class ChatInitial extends ChatState {
  const ChatInitial({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    super.isListening,
    super.temporaryVoiceText,
  });
}

class ChatTyping extends ChatState {
  const ChatTyping({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    super.isListening,
    super.temporaryVoiceText,
  });
}

class ChatSuccess extends ChatState {
  const ChatSuccess({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    super.isListening,
    super.temporaryVoiceText,
  });
}

class ChatError extends ChatState {
  final String message;

  const ChatError({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    required this.message,
    super.isListening,
    super.temporaryVoiceText,
  });
}

class ChatRecording extends ChatState {
  final double volume;

  const ChatRecording({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    super.isListening = true,
    this.volume = 0.0,
  });
}

class ChatVoiceProcessing extends ChatState {
  const ChatVoiceProcessing({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    super.isListening = false,
  });
}

class ChatVoiceReady extends ChatState {
  final String transcribedText;

  const ChatVoiceReady({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    required this.transcribedText,
    super.isListening = false,
  });
}

class ChatSpeechError extends ChatState {
  final String error;

  const ChatSpeechError({
    required super.sessions,
    super.currentChatId,
    required super.messages,
    required this.error,
    super.isListening = false,
    super.temporaryVoiceText,
  });
}
