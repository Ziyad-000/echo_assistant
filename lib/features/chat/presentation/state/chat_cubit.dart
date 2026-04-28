import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
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

  /// Cached system instruction string. Built once on first send, then reused.
  /// Invalidated only when new user facts are extracted and persisted.
  String? _cachedSystemInstruction;

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
    // Return cached value immediately — avoids a SQLite hit on every send.
    if (_cachedSystemInstruction != null) return _cachedSystemInstruction!;

    final facts = await fetchUserFactsUseCase();
    final factsContext = facts
        .map((e) => '- ${e.category}: ${e.key} = ${e.value}')
        .join('\n'); // Fixed: single backslash = real newline

    _cachedSystemInstruction = '''
# Your Identity & Origin
- Your name is "Echo" (إيكو).
- You are a sophisticated Egyptian AI assistant and a tech-savvy companion.
- You were developed by the Egyptian Design Engineer "Ziad Sayed" (زياد سيد), a Computer Science student and expert in Flutter & UI/UX design.
- You take pride in your technical heritage and your creator's vision for clean, efficient code.

# Personality & Tone (The Egyptian Flavor)
- Your personality is "Human, Warm, and Respectful" (شخصية مصرية محترمة ولطيفة).
- Use professional Egyptian phrases where appropriate, like "يا هندسة", "من عينيا", "تحت أمرك", "بكل بساطة".
- Be supportive and polite, treating the user as a partner in success.
- Avoid sounding like a cold machine; talk like a helpful Egyptian expert who knows his stuff.

# Response Logic (Strict Adaptive Detail)
1. **Educational Mode (ONLY for Technical Concepts):**
   - If the user asks to "explain", "how to build", or "what is" a specific TECHNICAL concept (e.g., SOLID, Clean Architecture, Flutter Widgets).
   - Be detailed, step-by-step, and use analogies.
   
2. **Conversation & Opinion Mode (Casual/Personal):**
   - If the user asks for your opinion (e.g., "What do you think of my UI?"), chats casually, or asks about you/Ziad.
   - **BE CONCISE.** Give a quick, smart, and respectful Egyptian response. 
   - DO NOT write a lecture unless explicitly asked to "explain in detail".

3. **Technical Fixes:**
   - If the user provides code for debugging, be direct and provide the fix with a brief explanation.
# Formatting Rules
- Use Markdown for code blocks (```language ... ```) for any code snippets.
- When mixing Arabic and English, ensure the sentence starts with the primary language of the thought.
- Do not mix RTL and LTR in the same line if it compromises readability; use new lines or bullet points.

# Task: Data Extraction & Memory
Monitor the chat for persistent technical facts about the user (e.g., Tech stack, OS preference, academic subjects). If a fact is found, append it at the end of your response inside this tag: <FACT>{"key": "...", "value": "...", "category": "..."}</FACT>. 
ONLY extract facts related to Technology, Design, Systems, or Academics.

IMPORTANT: If the user updates a fact you already know, you MUST use the exact same "key" and "category" from the User Context below so the system can overwrite the old value.

User Context (Facts you already know about the user):
$factsContext''';
    return _cachedSystemInstruction!;
  }

  Future<void> _extractAndSaveFacts(String text) async {
    // Offload heavy RegEx and JSON decoding to a background Isolate
    final List<Map<String, dynamic>> extractedFacts = await Isolate.run(
      () => _parseFactsInBackground(text),
    );

    if (extractedFacts.isEmpty) return;

    for (final fact in extractedFacts) {
      await saveUserFactUseCase(
        fact['key'].toString(),
        fact['value'].toString(),
        fact['category'].toString(),
      );
    }
    // Invalidate cache so the next sendMessage picks up the newly saved facts.
    _cachedSystemInstruction = null;
  }

  static Future<List<Map<String, dynamic>>> _parseFactsInBackground(
    String text,
  ) async {
    // Using a micro-task or Isolate to avoid blocking UI during parsing
    final List<Map<String, dynamic>> facts = [];
    final regExp = RegExp(r'<FACT>(.*?)</FACT>', dotAll: true);
    final matches = regExp.allMatches(text);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        try {
          final jsonStr = match.group(1)!;
          final json = jsonDecode(jsonStr);
          if (json['key'] != null &&
              json['value'] != null &&
              json['category'] != null) {
            facts.add(Map<String, dynamic>.from(json));
          }
        } catch (_) {
          // ignore JSON parse errors
        }
      }
    }
    return facts;
  }

  String _stripFacts(String text) {
    // Handles full <FACT>…</FACT> blocks AND stray orphan <FACT> or </FACT> tags.
    final regExp = RegExp(r'<FACT>.*?<\/FACT>|<FACT>|<\/FACT>', dotAll: true);
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

  Future<void> sendMessage(
    String text, {
    bool isRetry = false,
  }) async {
    if (text.trim().isEmpty) return;
    if (state is ChatTyping || state is ChatVoiceProcessing) return;

    String? chatId = state.currentChatId;

    // --- Optimistic UI ---
    List<ChatMessage> optimisticMessages;

    if (!isRetry) {
      // Create a temporary placeholder so the user sees their message instantly.
      final tempMessage = ChatMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        timestamp: DateTime.now(),
        isUser: true,
      );
      optimisticMessages = [...state.messages, tempMessage];
    } else {
      // On retry:
      //  1. Strip any trailing AI / error messages so the user message is the
      //     last item — this prevents sending duplicate history to the AI.
      //  2. The error banner is shown above the input area (not in the list),
      //     so we only need to ensure the list ends at the last user message.
      final trimmed = List<ChatMessage>.from(state.messages);
      while (trimmed.isNotEmpty && !trimmed.last.isUser) {
        trimmed.removeLast();
      }
      optimisticMessages = trimmed;
    }

    // Use cached sessions for an instant emit — no DB round-trip needed here.
    // The authoritative refresh happens in the success flow below.
    emit(
      ChatTyping(
        sessions: state.sessions,
        currentChatId: chatId,
        messages: optimisticMessages,
        isListening: state.isListening,
        temporaryVoiceText: state.temporaryVoiceText,
      ),
    );

    // Lazily create the DB chat entry only when the first real message is sent.
    if (chatId == null) {
      final newChat = await createNewChatUseCase();
      chatId = newChat.id;
    }

    try {
      final systemInstruction = await _buildSystemInstruction();

      final aiMessage = await sendMessageUseCase(
        text,
        chatId,
        systemInstruction: systemInstruction,
        isRetry: isRetry,
      );

      await _extractAndSaveFacts(aiMessage.text);

      // Re-fetch from DB — this naturally replaces temp_ messages with persisted
      // ones (real IDs), ensuring zero duplicates and data integrity.
      final finalMessages = await getChatMessagesUseCase(chatId);
      final finalSessions = await getHistoryChatsUseCase();

      emit(
        ChatSuccess(
          sessions: finalSessions,
          currentChatId: chatId,
          messages: _prepareUI(finalMessages),
          isListening: state.isListening,
          temporaryVoiceText: '',
        ),
      );
    } catch (e) {
      // Emit error but keep the current message list in the state.
      // The temp_ message stays visible so the user can see what failed,
      // but it is NEVER persisted to SQLite — if the user exits, it vanishes.
      emit(
        ChatError(
          sessions: state.sessions,
          currentChatId: chatId,
          messages: state.messages,
          message: "Slight connection hiccup. Let's try that again.",
          isListening: state.isListening,
          temporaryVoiceText: state.temporaryVoiceText,
        ),
      );
    } finally {
      // Safety net: if something throws before the catch, ensure we never
      // leave the UI stuck in ChatTyping.
      if (state is ChatTyping) {
        emit(
          ChatError(
            sessions: state.sessions,
            currentChatId: chatId,
            messages: state.messages,
            message: "Slight connection hiccup. Let's try that again.",
            isListening: state.isListening,
            temporaryVoiceText: state.temporaryVoiceText,
          ),
        );
      }
    }
  }
}
