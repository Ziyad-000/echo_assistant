import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/create_new_chat_usecase.dart';
import '../../domain/usecases/delete_chat_usecase.dart';
import '../../domain/usecases/get_amplitude_stream_usecase.dart';
import '../../domain/usecases/get_chat_messages_usecase.dart';
import '../../domain/usecases/get_history_chats_usecase.dart';
import '../../domain/usecases/process_audio_recording_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/start_recording_usecase.dart';
import '../../../memory/domain/usecases/fetch_user_facts_usecase.dart';
import '../../../memory/domain/usecases/save_user_fact_usecase.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final SendMessageUseCase sendMessageUseCase;
  final GetHistoryChatsUseCase getHistoryChatsUseCase;
  final GetChatMessagesUseCase getChatMessagesUseCase;
  final CreateNewChatUseCase createNewChatUseCase;
  final DeleteChatUseCase deleteChatUseCase;
  final StartRecordingUseCase startRecordingUseCase;
  final ProcessAudioRecordingUseCase processAudioRecordingUseCase;
  final GetAmplitudeStreamUseCase getAmplitudeStreamUseCase;

  final SaveUserFactUseCase saveUserFactUseCase;
  final FetchUserFactsUseCase fetchUserFactsUseCase;

  StreamSubscription<double>? _amplitudeSubscription;

  ChatCubit({
    required this.sendMessageUseCase,
    required this.getHistoryChatsUseCase,
    required this.getChatMessagesUseCase,
    required this.createNewChatUseCase,
    required this.deleteChatUseCase,
    required this.startRecordingUseCase,
    required this.processAudioRecordingUseCase,
    required this.getAmplitudeStreamUseCase,
    required this.saveUserFactUseCase,
    required this.fetchUserFactsUseCase,
  }) : super(const ChatInitial(sessions: [], messages: []));

  Future<String> _buildSystemInstruction() async {
    final facts = await fetchUserFactsUseCase();
    final factsContext = facts
        .map((e) => '- ${e.category}: ${e.key} = ${e.value}')
        .join('\\n');
    return '''You are an expert data extractor. Monitor the chat for persistent technical facts about the user (e.g., Tech stack, OS preference, University subjects). If a fact is found, append it at the end of your response inside this tag: <FACT>{"key": "...", "value": "...", "category": "..."}</FACT>. ONLY extract facts related to Technology, Design, Systems, or Academics.

IMPORTANT: If the user provides an update to a fact you already know, you MUST use the exact same "key" and "category" from the User Context below so the system can overwrite the old value.

User Context:
$factsContext''';
  }

  void _extractAndSaveFacts(String text) {
    final regExp = RegExp(r'<FACT>(.*?)</FACT>', dotAll: true);
    final matches = regExp.allMatches(text);
    for (final match in matches) {
      if (match.groupCount >= 1) {
        try {
          final jsonStr = match.group(1)!;
          final json = jsonDecode(jsonStr);
          final key = json['key'];
          final value = json['value'];
          final category = json['category'];
          if (key != null && value != null && category != null) {
            saveUserFactUseCase(
              key.toString(),
              value.toString(),
              category.toString(),
            );
          }
        } catch (e) {
          // ignore JSON parse errors
        }
      }
    }
  }

  String _stripFacts(String text) {
    final regExp = RegExp(r'<FACT>.*?</FACT>', dotAll: true);
    return text.replaceAll(regExp, '').trim();
  }

  List<ChatMessage> _prepareUI(List<ChatMessage> messages) {
    return messages
        .map(
          (m) => ChatMessage(
            id: m.id,
            text: _stripFacts(m.text),
            timestamp: m.timestamp,
            isUser: m.isUser,
          ),
        )
        .toList();
  }

  @override
  Future<void> close() {
    _amplitudeSubscription?.cancel();
    return super.close();
  }

  Future<void> loadChatHistory() async {
    final sessions = await getHistoryChatsUseCase();
    emit(
      ChatSuccess(
        sessions: sessions,
        currentChatId: state.currentChatId,
        messages: _prepareUI(state.messages),
        isListening: state.isListening,
        temporaryVoiceText: state.temporaryVoiceText,
      ),
    );

    // If no chat is active but we have history, maybe load the first one.
    // However, it's better to explicitly require user action to load history,
    // or we start a new chat if there are no sessions.
    if (sessions.isEmpty && state.currentChatId == null) {
      await startNewChat();
    }
  }

  Future<void> startNewChat() async {
    // Just reset the UI state. DB entry is created only upon first message.
    emit(
      ChatSuccess(
        sessions: state.sessions,
        currentChatId: null,
        messages: const [],
        isListening: state.isListening,
        temporaryVoiceText: state.temporaryVoiceText,
      ),
    );
  }

  Future<void> startRecording() async {
    try {
      await startRecordingUseCase();
      emit(
        ChatRecording(
          sessions: state.sessions,
          currentChatId: state.currentChatId,
          messages: state.messages,
          volume: 0.0,
        ),
      );

      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = getAmplitudeStreamUseCase().listen((volume) {
        if (state is ChatRecording) {
          emit(
            ChatRecording(
              sessions: state.sessions,
              currentChatId: state.currentChatId,
              messages: state.messages,
              volume: volume,
            ),
          );
        }
      });
    } catch (e) {
      emit(
        ChatSpeechError(
          sessions: state.sessions,
          currentChatId: state.currentChatId,
          messages: state.messages,
          error: "Microphone error: $e",
        ),
      );
    }
  }

  Future<void> stopAndProcess() async {
    _amplitudeSubscription?.cancel();
    emit(
      ChatVoiceProcessing(
        sessions: state.sessions,
        currentChatId: state.currentChatId,
        messages: state.messages,
      ),
    );

    try {
      final transcribedText = await processAudioRecordingUseCase();
      if (transcribedText != null && transcribedText.isNotEmpty) {
        emit(
          ChatVoiceReady(
            sessions: state.sessions,
            currentChatId: state.currentChatId,
            messages: state.messages,
            transcribedText: transcribedText,
          ),
        );
      } else {
        emit(
          ChatSuccess(
            sessions: state.sessions,
            currentChatId: state.currentChatId,
            messages: state.messages,
            isListening: false,
            temporaryVoiceText: '',
          ),
        );
      }
    } catch (e) {
      emit(
        ChatSpeechError(
          sessions: state.sessions,
          currentChatId: state.currentChatId,
          messages: state.messages,
          error: "Transcription failed: $e",
        ),
      );
    }
  }

  Future<void> switchToChat(String chatId) async {
    if (chatId == state.currentChatId) return;

    final messages = await getChatMessagesUseCase(chatId);
    emit(
      ChatSuccess(
        sessions: state.sessions,
        currentChatId: chatId,
        messages: _prepareUI(messages),
        isListening: state.isListening,
        temporaryVoiceText: state.temporaryVoiceText,
      ),
    );
  }

  Future<void> deleteChat(String chatId) async {
    await deleteChatUseCase(chatId);
    final updatedSessions = await getHistoryChatsUseCase();

    if (state.currentChatId == chatId) {
      if (updatedSessions.isNotEmpty) {
        await switchToChat(updatedSessions.first.id);
      } else {
        await startNewChat();
      }
    } else {
      emit(
        ChatSuccess(
          sessions: updatedSessions,
          currentChatId: state.currentChatId,
          messages: state.messages,
          isListening: state.isListening,
          temporaryVoiceText: state.temporaryVoiceText,
        ),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    String? chatId = state.currentChatId;

    if (chatId == null) {
      // Create chat in DB ONLY when the first message is sent
      final newChat = await createNewChatUseCase();
      chatId = newChat.id;
    }

    // 1. Append user message and show typing
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch
          .toString(), // Temp ID until DB assigns real one, wait model has UUID
      text: text,
      timestamp: DateTime.now(),
      isUser: true,
    );

    final updatedMessages = List<ChatMessage>.from(state.messages)
      ..add(userMessage);

    // Ensure sessions are refreshed if this was the first message (auto-naming might change title)
    final updatedSessions = await getHistoryChatsUseCase();

    emit(
      ChatTyping(
        sessions: updatedSessions,
        currentChatId: chatId,
        messages: updatedMessages,
        isListening: state.isListening,
        temporaryVoiceText: state.temporaryVoiceText,
      ),
    );

    try {
      final systemInstruction = await _buildSystemInstruction();

      // 2. Call usecase for AI response (which inherently saves to DB)
      final aiMessage = await sendMessageUseCase(
        text,
        chatId,
        systemInstruction: systemInstruction,
      );

      _extractAndSaveFacts(aiMessage.text);

      // Re-fetch messages strictly from DB just in case? Or append. Let's fetch from DB to get right IDs:
      final finalMessages = await getChatMessagesUseCase(chatId);
      final finalSessions = await getHistoryChatsUseCase();

      emit(
        ChatSuccess(
          sessions: finalSessions,
          currentChatId: chatId,
          messages: _prepareUI(finalMessages),
          isListening: state.isListening,
          temporaryVoiceText: '', // Clear recognized text after send
        ),
      );
    } catch (e) {
      emit(
        ChatError(
          sessions: state.sessions,
          currentChatId: chatId,
          messages: updatedMessages,
          message: e.toString(),
          isListening: state.isListening,
          temporaryVoiceText: state.temporaryVoiceText,
        ),
      );
    }
  }
}
