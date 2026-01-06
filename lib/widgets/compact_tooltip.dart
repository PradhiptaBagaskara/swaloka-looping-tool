import 'package:flutter/material.dart';

/// A compact tooltip widget that shows a help icon with hover information
class CompactTooltip extends StatelessWidget {
  const CompactTooltip({
    required this.message,
    this.iconSize = 14,
    this.maxWidth = 280,
    super.key,
  });

  final String message;
  final double iconSize;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.inverseSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      preferBelow: true,
      verticalOffset: 8,
      waitDuration: const Duration(milliseconds: 500),
      richMessage: WidgetSpan(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onInverseSurface,
              height: 1.5,
            ),
            softWrap: true,
          ),
        ),
      ),
      child: Icon(
        Icons.help_outline,
        size: iconSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
