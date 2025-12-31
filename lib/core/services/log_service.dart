import 'package:flutter/foundation.dart';

/// Log entry type
enum LogLevel { info, success, warning, error }

/// Global logger configuration
class LoggerConfig {
  static bool enableConsoleLogging = true;
  static bool enableFileLogging = false;
  static String? logFilePath;
  static LogLevel minimumLevel = LogLevel.info;

  /// Custom log handlers (for additional outputs)
  static final List<void Function(LogEntry)> _handlers = [];

  /// Add a custom log handler
  static void addHandler(void Function(LogEntry) handler) {
    _handlers.add(handler);
  }

  /// Remove a custom log handler
  static void removeHandler(void Function(LogEntry) handler) {
    _handlers.remove(handler);
  }

  /// Get all handlers
  static List<void Function(LogEntry)> get handlers => _handlers;
}

/// Hierarchical log entry that supports expandable sub-logs (like Docker)
class LogEntry {
  final LogLevel level;
  final String message;
  final List<LogEntry> subLogs;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    List<LogEntry>? subLogs,
    DateTime? timestamp,
  }) : subLogs = subLogs ?? [],
       timestamp = timestamp ?? DateTime.now() {
    // Automatically log to system when entry is created
    _logToSystem();
  }

  /// Check if this log entry is expandable
  bool get isExpandable => subLogs.isNotEmpty;

  /// Get formatted timestamp (HH:MM:SS.mmm)
  String get formattedTimestamp {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final millisecond = timestamp.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$millisecond';
  }

  /// Get message with timestamp prefix
  String get messageWithTimestamp => '[$formattedTimestamp] $message';

  /// Add a sublog to this entry
  void addSubLog(LogEntry subLog) {
    subLogs.add(subLog);
  }

  /// Add multiple sublogs to this entry
  void addSubLogs(List<LogEntry> logs) {
    subLogs.addAll(logs);
  }

  /// Create a simple log entry without sub-logs
  factory LogEntry.simple(LogLevel level, String message) {
    return LogEntry(level: level, message: message);
  }

  /// Create a log entry with sub-logs
  factory LogEntry.withSubLogs(
    LogLevel level,
    String message,
    List<LogEntry> subLogs,
  ) {
    return LogEntry(level: level, message: message, subLogs: subLogs);
  }

  /// Helper to create an info log
  static LogEntry info(String message) =>
      LogEntry.simple(LogLevel.info, message);

  /// Helper to create a success log
  static LogEntry success(String message) =>
      LogEntry.simple(LogLevel.success, message);

  /// Helper to create a warning log
  static LogEntry warning(String message) =>
      LogEntry.simple(LogLevel.warning, message);

  /// Helper to create an error log
  static LogEntry error(String message) =>
      LogEntry.simple(LogLevel.error, message);

  /// Helper to create an info log with sub-logs
  static LogEntry infoWithSubLogs(String message, List<LogEntry> subLogs) {
    return LogEntry.withSubLogs(LogLevel.info, message, subLogs);
  }

  @override
  String toString() {
    if (subLogs.isEmpty) return message;
    return '$message (${subLogs.length} sub-logs)';
  }

  /// Get color for log level
  String get levelColor {
    switch (level) {
      case LogLevel.info:
        return 'info';
      case LogLevel.success:
        return 'success';
      case LogLevel.warning:
        return 'warning';
      case LogLevel.error:
        return 'error';
    }
  }

  /// Get icon name for log level
  String get iconName {
    switch (level) {
      case LogLevel.info:
        return 'info';
      case LogLevel.success:
        return 'check_circle';
      case LogLevel.warning:
        return 'warning';
      case LogLevel.error:
        return 'error';
    }
  }

  /// Log this entry to system outputs (console, file, handlers)
  void _logToSystem() {
    // Check minimum level
    if (_shouldLog()) {
      // Console logging
      if (LoggerConfig.enableConsoleLogging) {
        _logToConsole();
      }

      // File logging
      if (LoggerConfig.enableFileLogging && LoggerConfig.logFilePath != null) {
        _logToFile();
      }

      // Custom handlers
      for (final handler in LoggerConfig.handlers) {
        try {
          handler(this);
        } catch (e) {
          // Ignore handler errors to prevent logging from breaking
        }
      }
    }
  }

  /// Check if this log should be logged based on minimum level
  bool _shouldLog() {
    final levelPriority = {
      LogLevel.info: 0,
      LogLevel.success: 1,
      LogLevel.warning: 2,
      LogLevel.error: 3,
    };

    return (levelPriority[level] ?? 0) >=
        (levelPriority[LoggerConfig.minimumLevel] ?? 0);
  }

  /// Log to console with color coding
  void _logToConsole() {
    // ANSI color codes
    const colors = {
      LogLevel.info: '\x1B[36m', // Cyan
      LogLevel.success: '\x1B[32m', // Green
      LogLevel.warning: '\x1B[33m', // Yellow
      LogLevel.error: '\x1B[31m', // Red
    };
    const reset = '\x1B[0m';

    final color = colors[level] ?? '';
    final prefix = _getLogPrefix();

    // Print with color
    debugPrint('$color$prefix$messageWithTimestamp$reset');

    // Print sublogs with indentation
    _printSubLogs(subLogs, indent: 1);
  }

  /// Get log prefix based on level
  String _getLogPrefix() {
    switch (level) {
      case LogLevel.info:
        return 'ℹ️  ';
      case LogLevel.success:
        return '✅ ';
      case LogLevel.warning:
        return '⚠️  ';
      case LogLevel.error:
        return '❌ ';
    }
  }

  /// Print sublogs recursively with indentation
  void _printSubLogs(List<LogEntry> logs, {required int indent}) {
    const colors = {
      LogLevel.info: '\x1B[36m',
      LogLevel.success: '\x1B[32m',
      LogLevel.warning: '\x1B[33m',
      LogLevel.error: '\x1B[31m',
    };
    const reset = '\x1B[0m';

    for (final log in logs) {
      final color = colors[log.level] ?? '';
      final indentation = '  ' * indent;
      debugPrint('$color$indentation└─ ${log.messageWithTimestamp}$reset');

      if (log.subLogs.isNotEmpty) {
        _printSubLogs(log.subLogs, indent: indent + 1);
      }
    }
  }

  /// Log to file
  void _logToFile() {
    // TODO: Implement file logging
    // This would write to LoggerConfig.logFilePath
    // For now, this is a placeholder
  }
}

/// Static logger utility for quick logging
class Logger {
  /// Log info message
  static LogEntry info(String message) => LogEntry.info(message);

  /// Log success message
  static LogEntry success(String message) => LogEntry.success(message);

  /// Log warning message
  static LogEntry warning(String message) => LogEntry.warning(message);

  /// Log error message
  static LogEntry error(String message) => LogEntry.error(message);
}
