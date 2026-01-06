import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

/// Widget for drag-and-drop file zone
class DropZoneWidget extends StatefulWidget {
  const DropZoneWidget({
    required this.label,
    required this.icon,
    required this.onFilesDropped,
    required this.onTap,
    this.onClear,
    super.key,
  });
  final String label;
  final IconData icon;
  final void Function(List<DropItem>) onFilesDropped;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;
    final borderRadius = baseFontSize * 0.86;

    return DropTarget(
      onDragDone: (details) {
        debugPrint('DND: Dropped ${details.files.length} files');
        for (final f in details.files) {
          debugPrint('DND: File path: ${f.path}');
        }
        setState(() => _isDragging = false);
        widget.onFilesDropped(details.files);
      },
      onDragEntered: (details) {
        debugPrint('DND: Drag entered');
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        debugPrint('DND: Drag exited');
        setState(() => _isDragging = false);
      },
      onDragUpdated: (details) {
        // debugPrint('DND: Drag updated at ${details.localPosition}');
      },
      child: Stack(
        children: [
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: baseFontSize * 7.14,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isDragging
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: _isDragging ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: _isDragging ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.icon,
                      color: _isDragging
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: baseFontSize * 2.29,
                    ),
                  ),
                  SizedBox(height: baseFontSize * 0.86),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isDragging
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: _isDragging
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onClear != null)
            Positioned(
              top: baseFontSize * 0.57,
              right: baseFontSize * 0.57,
              child: InkWell(
                onTap: widget.onClear,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Container(
                  padding: EdgeInsets.all(baseFontSize * 0.29),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Icon(
                    Icons.close,
                    size: baseFontSize * 1.14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
