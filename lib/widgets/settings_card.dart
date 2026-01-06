import 'package:flutter/material.dart';

/// A consistent card container for settings sections
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.child,
    this.title,
    this.padding,
    super.key,
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      padding: padding ?? EdgeInsets.all(baseFontSize * 1.14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(baseFontSize * 0.86),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: title != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: baseFontSize * 1.14),
                child,
              ],
            )
          : child,
    );
  }
}
