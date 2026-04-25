import 'dart:async';
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
  }) : super(const ChatInitial(sessions: [], messages: []));

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
        messages: state.messages,
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
        messages: messages,
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
      // 2. Call usecase for AI response (which inherently saves to DB)
      await sendMessageUseCase(text, chatId);

      // Re-fetch messages strictly from DB just in case? Or append. Let's fetch from DB to get right IDs:
      final finalMessages = await getChatMessagesUseCase(chatId);
      final finalSessions = await getHistoryChatsUseCase();

      emit(
        ChatSuccess(
          sessions: finalSessions,
          currentChatId: chatId,
          messages: finalMessages,
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
