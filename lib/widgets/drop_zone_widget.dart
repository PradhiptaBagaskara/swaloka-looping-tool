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
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isDragging
                    ? Colors.deepPurple.withValues(alpha: 0.15)
                    : Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDragging
                      ? Colors.deepPurpleAccent
                      : const Color(0xFF333333),
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
                          ? Colors.deepPurpleAccent
                          : Colors.grey[600],
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: _isDragging ? Colors.white : Colors.grey[600],
                      fontSize: 13,
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
              top: 8,
              right: 8,
              child: InkWell(
                onTap: widget.onClear,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
