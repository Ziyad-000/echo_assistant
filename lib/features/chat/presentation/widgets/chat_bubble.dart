import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({super.key, required this.text, required this.isUser});

  /// Returns [TextDirection.rtl] when [text] starts with an Arabic character
  /// (Unicode range U+0600–U+06FF). Markdown code blocks always return
  /// [TextDirection.ltr] regardless of content.
  TextDirection _getDirection(String text) {
    if (text.startsWith('```')) return TextDirection.ltr;
    if (text.isEmpty) return TextDirection.ltr;
    final firstCode = text.codeUnitAt(0);
    return (firstCode >= 0x0600 && firstCode <= 0x06FF)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 20),
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent, // AI uses gradient
                  gradient: isUser
                      ? null
                      : LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: isUser
                    ? Directionality(
                        textDirection: _getDirection(text),
                        child: Text(
                          text,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      )
                    : Directionality(
                        textDirection: _getDirection(text),
                        child: MarkdownBody(
                          data: text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.4,
                            ),
                            code: const TextStyle(
                              backgroundColor: Color(0xFF1E1E1E),
                              color: Color(0xFF4AF626), // Terminal green
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                            codeblockPadding: const EdgeInsets.all(16.0),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E), // IDE Dark
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
