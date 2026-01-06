import 'package:flutter/material.dart';

/// A modern color picker dialog with spectrum and sliders.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    required this.initialColor,
    super.key,
  });

  final Color initialColor;

  static Future<Color?> show(BuildContext context, Color initialColor) {
    return showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsvColor;
  final _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _updateHexField();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateHexField() {
    final color = _hsvColor.toColor();
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    _hexController.text =
        '${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '').toUpperCase();
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      }
    } on FormatException {
      // Invalid hex format
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsvColor.toColor();

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Pick Color',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Preview
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Saturation-Value picker
            SizedBox(
              height: 180,
              child: _SaturationValuePicker(
                hue: _hsvColor.hue,
                saturation: _hsvColor.saturation,
                value: _hsvColor.value,
                onChanged: (saturation, value) {
                  setState(() {
                    _hsvColor = _hsvColor
                        .withSaturation(saturation)
                        .withValue(value);
                    _updateHexField();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Hue slider
            SizedBox(
              height: 24,
              child: _HueSlider(
                hue: _hsvColor.hue,
                onChanged: (hue) {
                  setState(() {
                    _hsvColor = _hsvColor.withHue(hue);
                    _updateHexField();
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Quick presets
            Text(
              'Quick Colors',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            _QuickColors(
              onColorSelected: (color) {
                setState(() {
                  _hsvColor = HSVColor.fromColor(color);
                  _updateHexField();
                });
              },
            ),
            const SizedBox(height: 16),

            // Hex input
            Row(
              children: [
                Text(
                  '#',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'FFFFFF',
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLength: 6,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    onChanged: (value) {
                      final color = _hexToColor(value);
                      if (color != null) {
                        setState(() {
                          _hsvColor = HSVColor.fromColor(color);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, currentColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Saturation-Value picker (the main color square)
class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) =>
              _handleTouch(details.localPosition, constraints),
          onPanUpdate: (details) =>
              _handleTouch(details.localPosition, constraints),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _SaturationValuePainter(hue: hue),
                child: Stack(
                  children: [
                    Positioned(
                      left: saturation * constraints.maxWidth - 10,
                      top: (1 - value) * constraints.maxHeight - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTouch(Offset position, BoxConstraints constraints) {
    final newSaturation = (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final newValue = (1 - position.dy / constraints.maxHeight).clamp(0.0, 1.0);
    onChanged(newSaturation, newValue);
  }
}

class _SaturationValuePainter extends CustomPainter {
  _SaturationValuePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw hue background
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(rect, Paint()..color = hueColor);

    // Draw saturation gradient (white to transparent)
    const saturationGradient = LinearGradient(
      colors: [Colors.white, Color(0x00FFFFFF)],
    );
    canvas.drawRect(
      rect,
      Paint()..shader = saturationGradient.createShader(rect),
    );

    // Draw value gradient (transparent to black)
    final valueGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withValues(alpha: 0), Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = valueGradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue;
}

/// Hue slider (rainbow bar)
class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hue,
    required this.onChanged,
  });

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) =>
              _handleTouch(details.localPosition, constraints),
          onPanUpdate: (details) =>
              _handleTouch(details.localPosition, constraints),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _HuePainter(),
                child: Stack(
                  children: [
                    Positioned(
                      left: (hue / 360) * constraints.maxWidth - 4,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        decoration: BoxDecoration(
                          color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTouch(Offset position, BoxConstraints constraints) {
    final newHue = ((position.dx / constraints.maxWidth) * 360).clamp(
      0.0,
      360.0,
    );
    onChanged(newHue);
  }
}

class _HuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        for (int i = 0; i <= 360; i += 60)
          HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor(),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_HuePainter oldDelegate) => false;
}

/// Quick color presets
class _QuickColors extends StatelessWidget {
  const _QuickColors({required this.onColorSelected});

  final ValueChanged<Color> onColorSelected;

  static const List<Color> _colors = [
    Colors.black,
    Colors.white,
    Color(0xFF9E9E9E),
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _colors.map((color) {
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
