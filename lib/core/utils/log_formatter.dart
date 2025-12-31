import 'package:swaloka_looping_tool/core/services/log_service.dart';

/// Utility class for formatting log entries
class LogFormatter {
  /// Format a log entry with hierarchical indentation
  static String formatLogEntry(LogEntry entry, int level) {
    final indent = '  ' * level;
    final timestamp = entry.timestamp.toIso8601String();
    final levelStr = entry.level.name.toUpperCase();
    final buffer = StringBuffer(
      '$indent[$timestamp] [$levelStr] ${entry.message}',
    );

    if (entry.subLogs.isNotEmpty) {
      for (final subLog in entry.subLogs) {
        buffer.write('\n${formatLogEntry(subLog, level + 1)}');
      }
    }

    return buffer.toString();
  }

  /// Format multiple log entries
  static String formatLogEntries(List<LogEntry> logs) {
    return logs.map((log) => formatLogEntry(log, 0)).join('\n');
  }
}
