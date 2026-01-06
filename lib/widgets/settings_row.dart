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
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
    this.width = 70,
    super.key,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
          suffixIcon: Icon(
            Icons.edit,
            size: 14,
            color: Colors.grey[500],
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
