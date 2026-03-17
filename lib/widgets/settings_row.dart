import 'package:flutter/material.dart';

/// A consistent row layout for settings with label, hint, and trailing widget
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    required this.trailing,
    this.hint,
    this.icon,
    super.key,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: baseFontSize * 1.14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: baseFontSize * 0.86),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hint != null) ...[
                SizedBox(height: baseFontSize * 0.29),
                Text(
                  hint!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

/// A number input field for settings
class SettingsNumberInput extends StatelessWidget {
  const SettingsNumberInput({
    required this.initialValue,
    required this.onChanged,
    this.width,
    this.minWidth = 60,
    super.key,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final double? width;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    final inputField = TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: baseFontSize * 0.86,
          vertical: baseFontSize * 0.71,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(baseFontSize * 0.57),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(baseFontSize * 0.57),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(baseFontSize * 0.57),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );

    // If width is specified, use fixed width
    if (width != null) {
      return SizedBox(
        width: width,
        child: inputField,
      );
    }

    // Otherwise, use constrained box that can grow
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: 120,
      ),
      child: IntrinsicWidth(child: inputField),
    );
  }
}
