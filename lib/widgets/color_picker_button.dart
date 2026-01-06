import 'package:flutter/material.dart';

import 'package:swaloka_looping_tool/widgets/color_picker_dialog.dart';

/// A modern color picker button that shows selected color and opens picker.
class ColorPickerButton extends StatelessWidget {
  const ColorPickerButton({
    required this.color,
    required this.onColorChanged,
    this.size = 28,
    this.showLabel = true,
    this.showDropdownIcon = true,
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;
  final double size;
  final bool showLabel;
  final bool showDropdownIcon;

  String _colorToHex(Color color) {
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = color.computeLuminance() < 0.5;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openColorPicker(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color swatch with checkerboard for transparency indication
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      // Color fill
                      Container(color: color),
                      // Subtle inner highlight
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ],
                              stops: const [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ),
                      // Border
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _colorToHex(color),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _getColorName(color),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (showDropdownIcon) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getColorName(Color color) {
    // Common color names
    final colorNames = {
      0xFF000000: 'Black',
      0xFFFFFFFF: 'White',
      0xFF1A1A1A: 'Dark Gray',
      0xFF333333: 'Gray',
      0xFF666666: 'Medium Gray',
      0xFF999999: 'Light Gray',
      0xFFE91E63: 'Pink',
      0xFFF44336: 'Red',
      0xFFFF5722: 'Deep Orange',
      0xFFFF9800: 'Orange',
      0xFFFFC107: 'Amber',
      0xFFFFEB3B: 'Yellow',
      0xFFCDDC39: 'Lime',
      0xFF4CAF50: 'Green',
      0xFF009688: 'Teal',
      0xFF00BCD4: 'Cyan',
      0xFF03A9F4: 'Light Blue',
      0xFF2196F3: 'Blue',
      0xFF3F51B5: 'Indigo',
      0xFF9C27B0: 'Purple',
    };

    final colorArgb = color.toARGB32();
    if (colorNames.containsKey(colorArgb)) {
      return colorNames[colorArgb]!;
    }

    // Describe based on HSV
    final hsv = HSVColor.fromColor(color);
    if (hsv.saturation < 0.1) {
      if (hsv.value < 0.2) return 'Near Black';
      if (hsv.value > 0.8) return 'Near White';
      return 'Gray';
    }

    final hue = hsv.hue;
    if (hue < 15 || hue >= 345) return 'Red';
    if (hue < 45) return 'Orange';
    if (hue < 75) return 'Yellow';
    if (hue < 150) return 'Green';
    if (hue < 195) return 'Cyan';
    if (hue < 255) return 'Blue';
    if (hue < 285) return 'Purple';
    if (hue < 345) return 'Pink';

    return 'Custom';
  }

  Future<void> _openColorPicker(BuildContext context) async {
    final newColor = await ColorPickerDialog.show(context, color);
    if (newColor != null) {
      onColorChanged(newColor);
    }
  }
}
