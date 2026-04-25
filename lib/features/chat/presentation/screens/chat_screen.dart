import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/voice_action_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/network_info.dart';
import '../../../../injection_container.dart';
import '../state/chat_cubit.dart';
import '../state/chat_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  Timer? _thinkingTimer;
  int _thinkingDotCount = 0;
  String _savedTextBeforeProcessing = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    // Load history when screen is opened
    context.read<ChatCubit>().loadChatHistory();
  }

  void _onTextChanged() {
    final isTyping = _textController.text.isNotEmpty;
    if (isTyping != _isTyping) {
      setState(() {
        _isTyping = isTyping;
      });
    }
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Echo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const ChatHistoryDrawer(),
      body: BlocListener<ChatCubit, ChatState>(
        listenWhen: (previous, current) =>
            previous.messages.length != current.messages.length ||
            (previous is! ChatTyping && current is ChatTyping) ||
            current is ChatVoiceProcessing ||
            current is ChatVoiceReady ||
            current is ChatRecording ||
            current is ChatError ||
            current is ChatSpeechError,
        listener: (context, state) {
          debugPrint("🚨 UI State Changed to: $state");
          if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (state is ChatSpeechError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }

          if (state is ChatVoiceProcessing) {
            if (_textController.text.isNotEmpty) {
              _savedTextBeforeProcessing = _textController.text;
              _textController.clear();
            }
            _thinkingTimer?.cancel();
            _thinkingTimer = Timer.periodic(const Duration(milliseconds: 500), (
              timer,
            ) {
              setState(() {
                _thinkingDotCount = (_thinkingDotCount + 1) % 4;
              });
            });
          } else {
            _thinkingTimer?.cancel();
          }

          if (state is ChatVoiceReady && state.transcribedText.isNotEmpty) {
            final combinedText = _savedTextBeforeProcessing.isNotEmpty
                ? '$_savedTextBeforeProcessing ${state.transcribedText}'.trim()
                : state.transcribedText;
            _textController.text = combinedText;
            _savedTextBeforeProcessing = '';
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }

          // Trigger scroll whenever message count increases or typing starts
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        },
        child: BlocBuilder<ChatCubit, ChatState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    itemCount:
                        state.messages.length + (state is ChatTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length &&
                          state is ChatTyping) {
                        return const TypingIndicator();
                      }
                      final message = state.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ChatBubble(
                          text: message.text,
                          isUser: message.isUser,
                        ),
                      );
                    },
                  ),
                ),
                StreamBuilder<bool>(
                  stream: sl<INetworkInfo>().onConnectivityChanged,
                  initialData: true,
                  builder: (context, snapshot) {
                    final isConnected = snapshot.data ?? true;
                    return _buildInputArea(context, isConnected, state);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    bool isConnected,
    ChatState state,
  ) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No Internet Connection',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 5,
                          enabled: isConnected && state is! ChatVoiceProcessing,
                          decoration: InputDecoration(
                            hintText: state is ChatVoiceProcessing
                                ? 'Echo is transcribing your words${'.' * _thinkingDotCount}'
                                : 'Ask Echo...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 14.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceActionButton(
                  isConnected: isConnected,
                  isTyping: _isTyping,
                  state: state,
                  onPressed: () {
                    if (state is ChatRecording) {
                      context.read<ChatCubit>().stopAndProcess();
                    } else if (_isTyping) {
                      final text = _textController.text;
                      if (text.isNotEmpty) {
                        context.read<ChatCubit>().sendMessage(text);
                        _textController.clear();
                      }
                    } else {
                      context.read<ChatCubit>().startRecording();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
