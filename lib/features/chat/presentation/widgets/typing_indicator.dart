import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve theme color once per build — NOT inside AnimatedBuilder which
    // fires every 16ms. This prevents InheritedWidget tree-walks per frame.
    final dotColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              // Pass the dot as a pre-built child — it's only created once,
              // not on every animation tick.
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              builder: (context, child) {
                final offset = index * 0.2;
                final t = (_controller.value - offset) % 1.0;
                final phase = t < 0 ? t + 1 : t;

                final dy = phase < 0.5
                    ? -4.0 * (0.5 - (0.5 - phase).abs())
                    : 0.0;
                final opacity = phase < 0.5 ? 1.0 : 0.5;

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
