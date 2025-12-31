import 'dart:io';

/// Service for detecting system hardware capabilities
class SystemInfoService {
  /// Cached FFmpeg path
  static String? _ffmpegPath;

  /// Extended PATH with common installation directories
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
      final result = await Process.run('ffmpeg', [
        '-version',
      ],
        environment: extendedEnvironment,
        // runInShell: true needed for macOS release build compatibility, on startup check
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
    } catch (_) {}
    return null;
  }

  /// Check if FFmpeg is installed and available
  static Future<bool> isFFmpegAvailable({bool raiseException = false}) async {
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

  /// Get the number of CPU cores available
  static int get cpuCores {
    try {
      // On all platforms (Linux, macOS, Windows), use platform.numberOfProcessors
      return Platform.numberOfProcessors;
    } catch (e) {
      // Fallback to a safe default
      return 4;
    }
  }

  /// Get recommended concurrency limit based on CPU cores
  ///
  /// Recommendation formula:
  /// - For light workloads: 50% of CPU cores
  /// - For balanced workloads: 75% of CPU cores
  /// - For heavy workloads: 100% of CPU cores (or cores - 1)
  static int getRecommendedConcurrency({ConcurrentWorkload workload = ConcurrentWorkload.balanced}) {
    final cores = cpuCores;

    switch (workload) {
      case ConcurrentWorkload.light:
        // Use 50% of cores, minimum 2
        return (cores * 0.5).ceil().clamp(2, cores);
      case ConcurrentWorkload.balanced:
        // Use 75% of cores, minimum 2
        return (cores * 0.75).ceil().clamp(2, cores);
      case ConcurrentWorkload.heavy:
        // Use all cores, or cores - 1 to leave room for system
        return (cores > 1) ? cores - 1 : cores;
    }
  }

  /// Get CPU count information as a string
  static String getCpuInfo() {
    final cores = cpuCores;
    final recommended = getRecommendedConcurrency();
    return '$cores CPU cores detected (recommended: $recommended parallel tasks)';
  }

  /// Get maximum safe concurrency (leaves some CPU for system)
  static int get maxSafeConcurrency {
    return cpuCores > 1 ? cpuCores - 1 : cpuCores;
  }
}

/// Workload intensity for concurrency recommendations
enum ConcurrentWorkload {
  /// Light workload - use 50% of CPU cores
  light,

  /// Balanced workload - use 75% of CPU cores (recommended for most cases)
  balanced,

  /// Heavy workload - use all available CPU cores
  heavy,
}
