import 'dart:io';

import 'package:swaloka_looping_tool/core/services/log_service.dart';

/// Video metadata container
class VideoMetadata {
  const VideoMetadata({
    required this.codec,
    required this.width,
    required this.height,
    required this.fps,
    required this.pixFmt,
  });

  final String? codec;
  final int? width;
  final int? height;
  final String? fps;
  final String? pixFmt;
}

/// Service for handling FFmpeg operations
class FFmpegService {
  /// Cached FFmpeg path
  static String? _ffmpegPath;

  /// Cache for video metadata to avoid multiple ffprobe calls
  static final Map<String, VideoMetadata> _metadataCache = {};

  /// Extended PATH with common FFmpeg installation directories
  static Map<String, String> get extendedEnvironment {
    final env = Map<String, String>.from(Platform.environment);
    final currentPath = env['PATH'] ?? '';

    if (Platform.isWindows) {
      // Windows: common FFmpeg install locations
      final extraPaths = [
        r'C:\ffmpeg\bin',
        r'C:\Program Files\ffmpeg\bin',
        r'C:\Program Files (x86)\ffmpeg\bin',
      ];
      env['PATH'] = [...extraPaths, currentPath].join(';');
    } else {
      // macOS/Linux: Homebrew and system paths
      final extraPaths = [
        '/opt/homebrew/bin', // Apple Silicon Mac (Homebrew)
        '/usr/local/bin', // Intel Mac (Homebrew)
        '/usr/bin', // System
      ];
      env['PATH'] = [...extraPaths, currentPath].join(':');
    }

    return env;
  }

  /// Get the full path to FFmpeg executable
  static String get ffmpegPath => _ffmpegPath ?? 'ffmpeg';

  /// Get the full path to FFprobe executable
  static String get ffprobePath {
    if (_ffmpegPath != null) {
      // If we found ffmpeg at a specific path, look for ffprobe in the same directory
      final dir = File(_ffmpegPath!).parent.path;
      final ext = Platform.isWindows ? '.exe' : '';
      final probePath = '$dir${Platform.pathSeparator}ffprobe$ext';
      if (File(probePath).existsSync()) {
        return probePath;
      }
    }
    return 'ffprobe';
  }

  /// Find FFmpeg path using extended environment
  static Future<String?> _findFFmpegPath() async {
    if (_ffmpegPath != null) return _ffmpegPath;

    try {
      // Try with extended PATH
      if (Platform.isWindows) {
        final result = await Process.run('where', ['ffmpeg']);
        if (result.exitCode == 0) {
          _ffmpegPath = (result.stdout as String).trim().split('\n').first;
          return _ffmpegPath;
        }
      }
      final result = await Process.run(
        'ffmpeg',
        ['-version'],
        environment: extendedEnvironment,
        // runInShell: true needed for macOS release build compatibility
        runInShell: true,
      );
      if (result.exitCode == 0) {
        // Find the actual path using 'which' (Unix) or 'where' (Windows)
        final whichCmd = Platform.isWindows ? 'where' : 'which';
        final whichResult = await Process.run(whichCmd, [
          'ffmpeg',
        ], environment: extendedEnvironment);
        if (whichResult.exitCode == 0) {
          // 'where' on Windows may return multiple lines, take first
          _ffmpegPath = (whichResult.stdout as String).trim().split('\n').first;
        } else {
          _ffmpegPath = 'ffmpeg'; // Use with extended env
        }
        return _ffmpegPath;
      }
    } on Exception catch (_) {}
    return null;
  }

  /// Check if FFmpeg is installed and available
  static Future<bool> isAvailable({bool raiseException = false}) async {
    try {
      final path = await _findFFmpegPath();
      if (path == null) {
        if (raiseException) {
          throw Exception('FFmpeg not found');
        }
        return false;
      }
      return true;
    } catch (e) {
      if (raiseException) {
        throw Exception('FFmpeg is not installed or not accessible: $e');
      }
      return false;
    }
  }

  /// Reset cached FFmpeg path (useful for re-checking after installation)
  static void resetCache() {
    _ffmpegPath = null;
    _metadataCache.clear();
  }

  /// Clear video metadata cache (useful when files are modified)
  static void clearMetadataCache() {
    _metadataCache.clear();
  }

  /// Get comprehensive video metadata using a single ffprobe call
  /// Results are cached to avoid redundant calls for the same file
  static Future<VideoMetadata> getVideoMetadata(String filePath) async {
    // Check cache first
    if (_metadataCache.containsKey(filePath)) {
      return _metadataCache[filePath]!;
    }

    try {
      final result = await Process.run(
        ffprobePath,
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_streams',
          '-select_streams',
          'v:0',
          filePath,
        ],
        environment: extendedEnvironment,
      );

      if (result.exitCode == 0) {
        final jsonStr = result.stdout as String;

        // Parse codec
        final codecMatch = RegExp(
          r'"codec_name":\s*"([^"]+)"',
        ).firstMatch(jsonStr);
        final codec = codecMatch?.group(1);

        // Parse width and height
        final widthMatch = RegExp(
          r'"width":\s*(\d+)',
        ).firstMatch(jsonStr);
        final heightMatch = RegExp(
          r'"height":\s*(\d+)',
        ).firstMatch(jsonStr);
        final width = widthMatch != null
            ? int.tryParse(widthMatch.group(1)!)
            : null;
        final height = heightMatch != null
            ? int.tryParse(heightMatch.group(1)!)
            : null;

        // Parse FPS
        final rFrameRateMatch = RegExp(
          r'"r_frame_rate":\s*"([^"]+)"',
        ).firstMatch(jsonStr);
        String? fps;
        if (rFrameRateMatch != null) {
          final val = rFrameRateMatch.group(1)!;
          final parts = val.split('/');
          if (parts.length == 2) {
            final num = double.tryParse(parts[0]);
            final den = double.tryParse(parts[1]);
            if (num != null && den != null && den != 0) {
              fps = (num / den).toStringAsFixed(2);
              if (fps.endsWith('.00')) {
                fps = fps.substring(0, fps.length - 3);
              }
            }
          }
        }

        // Parse pixel format
        final pixFmtMatch = RegExp(
          r'"pix_fmt":\s*"([^"]+)"',
        ).firstMatch(jsonStr);
        final pixFmt = pixFmtMatch?.group(1);

        final metadata = VideoMetadata(
          codec: codec,
          width: width,
          height: height,
          fps: fps,
          pixFmt: pixFmt,
        );

        // Cache the result
        _metadataCache[filePath] = metadata;
        return metadata;
      }
    } on Exception catch (_) {}

    // Return empty metadata on failure
    const emptyMetadata = VideoMetadata(
      codec: null,
      width: null,
      height: null,
      fps: null,
      pixFmt: null,
    );
    _metadataCache[filePath] = emptyMetadata;
    return emptyMetadata;
  }

  /// Regex pattern for FFmpeg progress lines
  static final _progressPattern = RegExp(r'frame=\s*\d+|size=\s*\d+.*time=');

  /// Check if a line is a verbose progress line (should be filtered)
  static bool _isProgressLine(String line) {
    // FFmpeg progress lines: "frame=123 fps=60 q=-1.0 size=1024KiB time=00:01:23..."
    // These are very verbose and not useful in logs
    return _progressPattern.hasMatch(line) ||
        (line.contains('fps=') && line.contains('time=')) ||
        (line.contains('configuration')) ||
        (line.contains('bitrate=') && line.contains('speed='));
  }

  /// Check if a line is important (errors, warnings, or key info)
  static bool _isImportantLine(String line) {
    final lower = line.toLowerCase();
    // Errors, warnings, and important info
    return lower.contains('error') ||
        lower.contains('warning') ||
        lower.contains('failed') ||
        lower.contains('invalid') ||
        lower.contains('unable') ||
        lower.contains('cannot') ||
        lower.contains('could not') ||
        lower.contains('no such') ||
        lower.contains('input #') ||
        lower.contains('output #') ||
        lower.contains('stream #') ||
        lower.contains('duration:') ||
        lower.contains('avformat') ||
        lower.contains('encoder') ||
        lower.contains('avcodec');
  }

  /// Run FFmpeg command with hierarchical logging
  static Future<void> run(
    List<String> command, {
    String? errorMessage,
    void Function(LogEntry log)? onLog,
  }) async {
    // Get FFmpeg path and extended environment
    final ffmpegExecutable = ffmpegPath;
    final env = extendedEnvironment;

    // Create and show command log immediately
    final logCommand = [
      ffmpegExecutable,
      ...command.map((arg) => arg.contains(' ') ? '"$arg"' : arg),
    ].join(' ');

    final commandLog = LogEntry.info('Command: $logCommand');
    onLog?.call(commandLog);

    final startTime = DateTime.now();

    // Run FFmpeg with extended PATH environment
    // Use the resolved executable path directly and avoid runInShell
    // to prevent complex quoting issues with paths containing spaces.
    final result = await Process.run(
      ffmpegExecutable,
      command,
      environment: env,
    );

    final exitCode = result.exitCode;

    // Parse stdout - keep all (usually minimal)
    final stdoutLogs = <LogEntry>[];
    final stdoutStr = result.stdout as String;
    if (stdoutStr.isNotEmpty) {
      for (final line in stdoutStr.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          stdoutLogs.add(LogEntry.simple(LogLevel.info, trimmed));
        }
      }
    }

    // Parse stderr
    final stderrStr = result.stderr as String;
    final stderrLines = stderrStr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final executionDuration = DateTime.now().difference(startTime);

    // On failure: keep last 100 lines for debugging
    // On success: filter out verbose progress lines
    final stderrLogs = <LogEntry>[];
    var skippedLines = 0;
    var stderrNote = '';

    if (exitCode != 0 && stderrLines.isNotEmpty) {
      // Keep last 100 lines for debugging
      const tailCount = 100;
      final totalLines = stderrLines.length;
      final linesToShow = stderrLines.length > tailCount
          ? stderrLines.sublist(stderrLines.length - tailCount)
          : stderrLines;

      for (final line in linesToShow) {
        final level = _isImportantLine(line) ? LogLevel.error : LogLevel.info;
        stderrLogs.add(LogEntry.simple(level, line));
      }

      if (totalLines > tailCount) {
        stderrNote = ' (showing last $tailCount of $totalLines lines)';
      }
    } else if (stderrLines.isNotEmpty) {
      // Success: filter progress lines
      for (final line in stderrLines) {
        if (_isProgressLine(line)) {
          skippedLines++;
          continue;
        }
        final level = _isImportantLine(line) ? LogLevel.warning : LogLevel.info;
        stderrLogs.add(LogEntry.simple(level, line));
      }

      if (skippedLines > 0) {
        stderrNote = ' ($skippedLines progress lines filtered)';
      }
    }

    // Add stdout/stderr directly to command log (flat structure)
    if (stdoutLogs.isNotEmpty) {
      commandLog.addSubLog(
        LogEntry.withSubLogs(
          LogLevel.info,
          'stdout (${stdoutLogs.length} lines)',
          stdoutLogs,
        ),
      );
    }

    if (stderrLogs.isNotEmpty || skippedLines > 0) {
      commandLog.addSubLog(
        LogEntry.withSubLogs(
          exitCode != 0 ? LogLevel.error : LogLevel.info,
          'stderr (${stderrLogs.length} lines$stderrNote)',
          stderrLogs,
        ),
      );
    }

    // Add duration
    commandLog.addSubLog(
      exitCode == 0
          ? LogEntry.success(
              'Completed in ${_formatDuration(executionDuration)}',
            )
          : LogEntry.error('Failed in ${_formatDuration(executionDuration)}'),
    );

    if (exitCode != 0) {
      final errorLog = LogEntry.error(
        'FFmpeg command failed with exit code $exitCode',
      );
      onLog?.call(errorLog);
      throw Exception(errorMessage ?? 'FFmpeg command failed');
    }
  }

  /// Verify FFmpeg installation with logging
  static Future<void> verifyInstallation(
    void Function(LogEntry log)? onLog,
  ) async {
    onLog?.call(LogEntry.info('Checking if ffmpeg exists in system path...'));
    await isAvailable(raiseException: true);
    onLog?.call(LogEntry.success('FFmpeg CLI found in system path.'));
  }

  /// Format duration for display
  static String _formatDuration(Duration duration) {
    if (duration.inSeconds == 0) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inSeconds < 60) {
      final seconds = duration.inMilliseconds / 1000;
      return '${seconds.toStringAsFixed(1)}s';
    } else {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }

  /// Get video codec name using cached metadata
  static Future<String?> getVideoCodec(String filePath) async {
    final metadata = await getVideoMetadata(filePath);
    return metadata.codec;
  }

  /// Get video resolution (width, height) using cached metadata
  static Future<({int width, int height})?> getVideoResolution(
    String filePath,
  ) async {
    final metadata = await getVideoMetadata(filePath);
    if (metadata.width != null && metadata.height != null) {
      return (width: metadata.width!, height: metadata.height!);
    }
    return null;
  }
}
