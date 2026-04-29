import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

// ─────────────────────────────────────────────────────────────────────────────
// CodeElementBuilder
// Intercepts <pre><code> markdown elements and renders a premium code block:
//   • Forced LTR direction — isolated from the app's global Arabic/RTL context
//   • Horizontal scrolling   — code lines never wrap
//   • Professional charcoal IDE palette
//   • Stateful "Copy" button with 2-second ✓ feedback
// ─────────────────────────────────────────────────────────────────────────────
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Only intercept fenced/block code (the <code> child of a <pre> element).
    // Inline `code` spans are handled by MarkdownStyleSheet.code directly.
    final isBlock =
        element.tag == 'code' &&
        (element.attributes['class'] != null ||
            (parentStyle?.fontSize ?? 0) < 15);

    if (!isBlock) return null; // fall through to default inline rendering

    final rawCode = element.textContent;

    return Directionality(
      // HIGHEST PRIORITY: hard-isolate the entire code block from any
      // parent RTL Directionality widget (Arabic conversation context).
      textDirection: TextDirection.ltr,
      child: _CodeBlock(code: rawCode),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CodeBlock — stateful widget that owns the copy-button state
// ─────────────────────────────────────────────────────────────────────────────
class _CodeBlock extends StatefulWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;
  Timer? _resetTimer;

  void _onCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Stack(
        children: [
          // ── Code text with horizontal scroll ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 32, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                widget.code,
                textAlign: TextAlign.left,
                softWrap: false, // never wrap — scroll instead
                style: const TextStyle(
                  color: Color(0xFFD4D4D4),
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  height: 1.55,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          // ── Copy button (top-right, stacked above code) ───────────────────
          Positioned(
            top: 6,
            right: 6,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _copied
                  ? _CopyChip(
                      key: const ValueKey('done'),
                      icon: Icons.done_all_rounded,
                      label: 'Copied',
                      color: Colors.greenAccent,
                    )
                  : _CopyChip(
                      key: const ValueKey('copy'),
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      color: Colors.white54,
                      onTap: _onCopy,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CopyChip — the small pill button shown in the top-right of a code block
// ─────────────────────────────────────────────────────────────────────────────
class _CopyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _CopyChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatBubble
// ─────────────────────────────────────────────────────────────────────────────
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: isUser
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06))
                : (isDark
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08)),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
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
                  // Outer direction follows the message language (RTL/LTR).
                  // CodeElementBuilder re-wraps each code block in its own
                  // forced-LTR Directionality, so Arabic context cannot bleed in.
                  textDirection: _getDirection(text),
                  child: MarkdownBody(
                    data: text,
                    builders: {
                      // 'code' covers both inline and fenced blocks.
                      // CodeElementBuilder inspects context and only intercepts
                      // block-level code, returning null for inline spans.
                      'code': CodeElementBuilder(),
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      // Inline code style (not overridden by CodeElementBuilder)
                      code: TextStyle(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: const Color(0xFFD4D4D4),
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      // Keep codeblock styles as fallback — CodeElementBuilder
                      // takes priority for block code via the builders map.
                      codeblockPadding: EdgeInsets.zero,
                      codeblockDecoration: const BoxDecoration(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
