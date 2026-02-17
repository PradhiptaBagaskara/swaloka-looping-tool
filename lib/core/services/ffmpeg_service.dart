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
    required this.duration,
    required this.hasAudio,
    this.audioCodec,
    this.metadataTags = const {},
  });

  final String? codec;
  final int? width;
  final int? height;
  final String? fps;
  final String? pixFmt;
  final Duration? duration;
  final bool hasAudio;
  final String? audioCodec;
  final Map<String, String> metadataTags;
}

/// Service for handling FFmpeg operations
class FFmpegService {
  /// Cached FFmpeg path (auto-detected)
  static String? _ffmpegPath;

  /// Custom FFmpeg path set by user (takes priority over auto-detect)
  static String? _customFfmpegPath;

  /// Hardware acceleration encoder setting
  static String _hwAccelEncoder = 'libx264';

  /// Currently running FFmpeg process (for cancellation)
  static Process? _currentProcess;

  /// Cancel the currently running FFmpeg process
  static Future<void> cancel() async {
    final process = _currentProcess;
    if (process != null) {
      try {
        // Try graceful shutdown first
        process.kill();
        // Wait a bit for graceful shutdown
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Force kill if still running
        process.kill(ProcessSignal.sigkill);
      } on Exception {
        // Ignore errors during cancellation
      }
      _currentProcess = null;
    }
  }

  /// Check if a process is currently running
  static bool get isProcessing => _currentProcess != null;

  /// Cache version - increment this when VideoMetadata schema changes
  static const int _cacheVersion = 3;

  /// Cache for video metadata to avoid multiple ffprobe calls
  static final Map<String, VideoMetadata> _metadataCache = {};
  static int _currentCacheVersion = 0;

  /// Set a custom FFmpeg path (overrides auto-detection)
  static void setCustomPath(String path) {
    _customFfmpegPath = path;
    _ffmpegPath = null; // Clear auto-detected cache
  }

  /// Clear custom path and revert to auto-detection
  static void clearCustomPath() {
    _customFfmpegPath = null;
    _ffmpegPath = null;
  }

  /// Check if using custom path
  static bool get hasCustomPath =>
      _customFfmpegPath != null && _customFfmpegPath!.isNotEmpty;

  /// Get the custom path (if set)
  static String? get customPath => _customFfmpegPath;

  /// Set hardware acceleration encoder
  static void setHwAccelEncoder(String encoder) {
    _hwAccelEncoder = encoder;
  }

  /// Get hardware acceleration encoder
  static String get hwAccelEncoder => _hwAccelEncoder;

  /// Public method to detect available hardware encoder
  /// Returns the detected encoder name (e.g., 'h264_nvenc', 'h264_amf', etc.)
  static Future<String> detectHardwareEncoder() async {
    return _detectHardwareEncoder();
  }

  /// Get video metadata flags for YouTube
  static Future<List<String>> getStandardYouTubeVideoMetadataFlags() async {
    return [
      '-bsf:v',
      'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1',
    ];
  }

  /// Detect available hardware encoder based on platform and FFmpeg support
  static Future<String> _detectHardwareEncoder() async {
    // Test which hardware encoders actually work
    final nvencWorks = await _testEncoderWorks('h264_nvenc');
    final amfWorks = await _testEncoderWorks('h264_amf');
    final qsvWorks = await _testEncoderWorks('h264_qsv');
    final mfWorks = await _testEncoderWorks('h264_mf');
    final videotoolboxWorks = await _testEncoderWorks('h264_videotoolbox');
    final vaapiWorks = await _testEncoderWorks('h264_vaapi');
    final v4l2m2mWorks = await _testEncoderWorks('h264_v4l2m2m');

    // Platform-based priority
    if (Platform.isMacOS) {
      return videotoolboxWorks ? 'h264_videotoolbox' : 'libx264';
    } else if (Platform.isWindows) {
      // Windows priority: NVENC > AMF > QuickSync > Media Foundation
      if (nvencWorks) return 'h264_nvenc';
      if (amfWorks) return 'h264_amf';
      if (qsvWorks) return 'h264_qsv';
      if (mfWorks) return 'h264_mf';
      return 'libx264';
    } else if (Platform.isLinux) {
      // Linux priority: NVENC > VA-API > V4L2
      if (nvencWorks) return 'h264_nvenc';
      if (vaapiWorks) return 'h264_vaapi';
      if (v4l2m2mWorks) return 'h264_v4l2m2m';
      return 'libx264';
    }

    // Fallback for other platforms
    return 'libx264';
  }

  /// Test if an encoder actually works by doing a tiny test encode
  /// This checks both:
  /// 1. If the encoder is built into FFmpeg
  /// 2. If the hardware/driver is actually available
  static Future<bool> _testEncoderWorks(String encoderName) async {
    try {
      // Create a 1-second test video with color source and try to encode it
      final result = await Process.run(
        ffmpegPath,
        [
          '-hide_banner',
          '-f', 'lavfi',
          '-i', 'color=c=black:s=320x240:d=1',
          '-c:v', encoderName,
          '-an', // No audio
          '-f', 'null', // Output to nowhere
          '-', // Use stdout as null device
        ],
        environment: extendedEnvironment,
      );

      // Exit code 0 means the encoder worked
      return result.exitCode == 0;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Validate a FFmpeg path by checking if executable exists and works
  static Future<bool> validatePath(String path) async {
    try {
      final result = await Process.run(path, [
        '-version',
      ], environment: extendedEnvironment);
      return result.exitCode == 0;
    } on Exception catch (_) {
      return false;
    }
  }

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
  static String get ffmpegPath {
    // Custom path takes priority
    if (_customFfmpegPath != null && _customFfmpegPath!.isNotEmpty) {
      return _customFfmpegPath!;
    }
    return _ffmpegPath ?? 'ffmpeg';
  }

  /// Get the full path to FFprobe executable
  static String get ffprobePath {
    // Derive ffprobe path from ffmpeg path (same directory)
    final currentFfmpegPath = _customFfmpegPath ?? _ffmpegPath;
    if (currentFfmpegPath != null) {
      final dir = File(currentFfmpegPath).parent.path;
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
    // Custom path takes priority
    if (_customFfmpegPath != null && _customFfmpegPath!.isNotEmpty) {
      return _customFfmpegPath;
    }
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
    _currentCacheVersion = 0;
  }

  /// Clear video metadata cache (useful when files are modified)
  static void clearMetadataCache() {
    _metadataCache.clear();
    _currentCacheVersion = _cacheVersion;
  }

  /// Get comprehensive video metadata using a single ffprobe call
  /// Results are cached to avoid redundant calls for the same file
  static Future<VideoMetadata> getVideoMetadata(String filePath) async {
    // Clear cache if schema version changed
    if (_currentCacheVersion != _cacheVersion) {
      _metadataCache.clear();
      _currentCacheVersion = _cacheVersion;
    }

    // Check cache first
    if (_metadataCache.containsKey(filePath)) {
      return _metadataCache[filePath]!;
    }

    try {
      final result = await Process.run(ffprobePath, [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        '-select_streams',
        'v:0',
        filePath,
      ], environment: extendedEnvironment);

      if (result.exitCode == 0) {
        final jsonStr = result.stdout as String;

        // Parse codec
        final codecMatch = RegExp(
          r'"codec_name":\s*"([^"]+)"',
        ).firstMatch(jsonStr);
        final codec = codecMatch?.group(1);

        // Parse width and height
        final widthMatch = RegExp(r'"width":\s*(\d+)').firstMatch(jsonStr);
        final heightMatch = RegExp(r'"height":\s*(\d+)').firstMatch(jsonStr);
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

        // Parse duration from format section
        final durationMatch = RegExp(
          r'"duration":\s*"([^"]+)"',
        ).firstMatch(jsonStr);
        Duration? duration;
        if (durationMatch != null) {
          final durationSeconds = double.tryParse(durationMatch.group(1)!);
          if (durationSeconds != null) {
            duration = Duration(
              microseconds: (durationSeconds * 1000000).round(),
            );
          }
        }

        // Check for audio streams and get audio codec
        final audioInfo = await _getAudioInfo(filePath);

        // Extract metadata tags
        final metadataTags = _extractMetadataTags(jsonStr);

        final metadata = VideoMetadata(
          codec: codec,
          width: width,
          height: height,
          fps: fps,
          pixFmt: pixFmt,
          duration: duration,
          hasAudio: audioInfo.hasAudio,
          audioCodec: audioInfo.codec,
          metadataTags: metadataTags,
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
      duration: null,
      hasAudio: false,
    );
    _metadataCache[filePath] = emptyMetadata;
    return emptyMetadata;
  }

  /// Get audio stream information (has audio and codec)
  static Future<({bool hasAudio, String? codec})> _getAudioInfo(
    String filePath,
  ) async {
    try {
      final result = await Process.run(ffprobePath, [
        '-v',
        'quiet',
        '-select_streams',
        'a:0',
        '-show_entries',
        'stream=codec_name',
        '-of',
        'csv=p=0',
        filePath,
      ], environment: extendedEnvironment);

      if (result.exitCode == 0) {
        final codec = (result.stdout as String).trim();
        if (codec.isNotEmpty) {
          return (hasAudio: true, codec: codec);
        }
      }
    } on Exception catch (_) {}
    return (hasAudio: false, codec: null);
  }

  /// Extract metadata tags from ffprobe JSON output
  static Map<String, String> _extractMetadataTags(String jsonStr) {
    final tags = <String, String>{};

    // Define all possible metadata fields to extract
    final metadataFields = {
      'title': 'Title',
      'artist': 'Artist',
      'author': 'Author',
      'album_artist': 'Album Artist',
      'album': 'Album',
      'comment': 'Comment',
      'description': 'Description',
      'synopsis': 'Synopsis',
      'copyright': 'Copyright',
      'creation_time': 'Creation Date',
      'date': 'Date',
      'year': 'Year',
      'encoder': 'Encoder',
      'encoded_by': 'Encoded By',
      'genre': 'Genre',
      'track': 'Track',
      'disc': 'Disc',
      'publisher': 'Publisher',
      'service_name': 'Service Name',
      'service_provider': 'Service Provider',
      'language': 'Language',
      'rating': 'Rating',
      'director': 'Director',
      'producer': 'Producer',
      'composer': 'Composer',
      'performer': 'Performer',
      'lyrics': 'Lyrics',
      'network': 'Network',
      'show': 'Show',
      'episode_id': 'Episode ID',
      'season_number': 'Season Number',
      'episode_sort': 'Episode Sort',
    };

    // Extract each field if it exists
    for (final entry in metadataFields.entries) {
      final pattern = '"${entry.key}":\\s*"([^"]*)"';
      final match = RegExp(pattern).firstMatch(jsonStr);
      if (match != null && match.group(1)!.isNotEmpty) {
        tags[entry.value] = match.group(1)!;
      }
    }

    return tags;
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

    // Start FFmpeg process (not run - so we can cancel it)
    final process = await Process.start(
      ffmpegExecutable,
      command,
      environment: env,
    );

    // Store for cancellation
    _currentProcess = process;

    // Capture output
    final stdoutLogs = <LogEntry>[];
    final stdout = <int>[];
    final stderr = <int>[];

    // Listen to stdout
    process.stdout.listen(stdout.addAll);

    // Listen to stderr
    process.stderr.listen(stderr.addAll);

    // Wait for process to complete
    final exitCode = await process.exitCode;

    // Clear current process when done
    _currentProcess = null;

    // Decode stdout
    final stdoutStr = String.fromCharCodes(stdout).trim();
    if (stdoutStr.isNotEmpty) {
      for (final line in stdoutStr.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          stdoutLogs.add(LogEntry.simple(LogLevel.info, trimmed));
        }
      }
    }

    // Decode stderr
    final stderrStr = String.fromCharCodes(stderr).trim();
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
    final durationLog = exitCode == 0
        ? LogEntry.success('Completed in ${_formatDuration(executionDuration)}')
        : LogEntry.error('Failed in ${_formatDuration(executionDuration)}');
    onLog?.call(durationLog);

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
