import 'package:flutter/material.dart';

/// A compact, consistent dropdown widget for settings
class CompactDropdown<T> extends StatelessWidget {
  const CompactDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.icon,
    this.isDense = true,
    this.labelStyle,
    super.key,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final IconData? icon;
  final bool isDense;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
        ],
        if (label != null) ...[
          Text(
            label!,
            style:
                labelStyle ??
                Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDense ? 8 : 12,
            vertical: isDense ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(isDense ? 6 : 8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: DropdownButton<T>(
            value: value,
            underline: const SizedBox(),
            dropdownColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            isDense: isDense,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: isDense ? 12 : 14,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
