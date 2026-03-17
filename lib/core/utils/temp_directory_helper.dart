import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/log_service.dart';

/// Helper for creating temporary directories across the app.
class TempDirectoryHelper {
  /// Creates a temporary directory for media processing.
  ///
  /// On macOS/Linux: uses system temp (faster, no indexing)
  /// On Windows: uses temp dir in project directory (no admin required)
  static Future<Directory> create({
    String? fallbackBasePath,
    String prefix = 'swaloka_temp',
    void Function(LogEntry log)? onLog,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    Directory tempDir;

    if (!Platform.isWindows) {
      try {
        final systemTemp = Directory.systemTemp;
        tempDir = Directory(
          p.join(systemTemp.path, '${prefix}_$timestamp'),
        );
        await tempDir.create(recursive: true);
      } on Exception catch (_) {
        // Fall back to provided path or current directory
        final basePath = fallbackBasePath ?? Directory.current.path;
        tempDir = Directory(
          p.join(basePath, 'temp', '${prefix}_$timestamp'),
        );
        await tempDir.create(recursive: true);
      }
    } else {
      // Windows: use temp directory in project folder
      final basePath = fallbackBasePath ?? Directory.current.path;
      tempDir = Directory(
        p.join(basePath, 'temp', '${prefix}_$timestamp'),
      );
      await tempDir.create(recursive: true);
    }

    onLog?.call(LogEntry.info('Temp directory created: ${tempDir.path}'));
    return tempDir;
  }
}
