import 'package:flutter/material.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';

class LogEntryWidget extends StatefulWidget {
  final LogEntry entry;
  final int level;

  const LogEntryWidget({required this.entry, this.level = 0, super.key});

  @override
  State<LogEntryWidget> createState() => _LogEntryWidgetState();
}

class _LogEntryWidgetState extends State<LogEntryWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(widget.entry.level);
    final levelIcon = _getLevelIcon(widget.entry.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main log entry
        InkWell(
          onTap: widget.entry.isExpandable
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 8 + widget.level * 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(levelIcon, size: 16, color: levelColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.entry.messageWithTimestamp,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (widget.entry.isExpandable)
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: levelColor,
                  ),
              ],
            ),
          ),
        ),
        // Expandable sub-logs
        if (widget.entry.isExpandable && _isExpanded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.entry.subLogs.map((subLog) {
              return LogEntryWidget(entry: subLog, level: widget.level + 1);
            }).toList(),
          ),
      ],
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue.shade400;
      case LogLevel.success:
        return Colors.green.shade400;
      case LogLevel.warning:
        return Colors.orange.shade400;
      case LogLevel.error:
        return Colors.red.shade400;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.success:
        return Icons.check_circle_outline;
      case LogLevel.warning:
        return Icons.warning_amber_outlined;
      case LogLevel.error:
        return Icons.error_outline;
    }
  }
}
