import 'dart:ui';
import 'package:flutter/material.dart';

import '../state/chat_state.dart';

class VoiceActionButton extends StatelessWidget {
  final bool isConnected;
  final bool isTyping;
  final ChatState state;
  final VoidCallback onPressed;

  const VoiceActionButton({
    super.key,
    required this.isConnected,
    required this.isTyping,
    required this.state,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final double volume = state is ChatRecording
        ? (state as ChatRecording).volume
        : 0.0;
    final bool isRecording = state is ChatRecording;
    final bool isProcessing = state is ChatVoiceProcessing;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Glowing background for Pulse
    final pulseScale = isRecording ? 1.0 + (volume * 0.8) : 1.0;

    return SizedBox(
      width: 52, // Leaves room for the loading ring
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Pulse Layer (Scale mapped to voice amplitude)
          if (isRecording)
            AnimatedScale(
              scale: pulseScale,
              duration: const Duration(milliseconds: 50),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

          // Middle Glassmorphism Layer (The solid button)
          ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnected && (isTyping || isRecording)
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : theme.colorScheme.primary.withValues(
                                alpha: 0.05,
                              )),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: isProcessing ? null : onPressed,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      isRecording
                          ? Icons.stop_rounded
                          : isTyping
                          ? Icons.send_rounded
                          : Icons.mic_none_rounded,
                      key: ValueKey<String>(
                        isProcessing
                            ? 'loading'
                            : (isRecording
                                  ? 'stop'
                                  : (isTyping ? 'send' : 'mic_none')),
                      ),
                      color: isConnected && (isTyping || isRecording)
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Foreground Loading Ring (Wrapped completely AROUND the button limits)
          if (isProcessing)
            SizedBox(
              width: 50, // Perfect wrapper bound
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: theme.colorScheme.primary, // Sleek bounding color
              ),
            ),
        ],
      ),
    );
  }
}
