import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

/// A professional hardware discovery service that makes it easy to detect
/// CPU, GPU, and encoding capabilities across platforms.
class HardwareService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get high-level system information (CPU cores, OS version, etc.)
  Future<Map<String, dynamic>> getSystemInfo() async {
    if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      return {
        'model': info.model,
        'os': 'macOS ${info.osRelease}',
        'cores': Platform.numberOfProcessors,
        'memory': '${(info.memorySize / (1024 * 1024 * 1024)).round()} GB',
      };
    } else if (Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      return {
        'model': info.productName,
        'os': 'Windows ${info.displayVersion}',
        'cores': Platform.numberOfProcessors,
        'computerName': info.computerName,
      };
    }
    return {'cores': Platform.numberOfProcessors};
  }

  /// Detect the best available hardware encoder for the current system.
  ///
  /// Returns the encoder name (e.g., 'h264_videotoolbox', 'h264_nvenc')
  /// or null if only CPU is available.
  Future<String?> detectBestEncoder() async {
    if (Platform.isMacOS) {
      return 'h264_videotoolbox'; // macOS always has VideoToolbox
    }

    if (Platform.isWindows) {
      // For Windows, we check FFmpeg's reported encoders directly.
      // This is the most reliable way to know what FFmpeg can actually use.
      try {
        final result = await Process.run('ffmpeg', ['-encoders']);
        final output = result.stdout.toString();

        if (output.contains('h264_nvenc')) return 'h264_nvenc'; // NVIDIA
        if (output.contains('h264_qsv')) return 'h264_qsv';     // Intel
        if (output.contains('h264_amf')) return 'h264_amf';     // AMD
      } catch (e) {
        // FFmpeg not found in PATH
      }
    }

    return null; // Fallback to CPU (libx264)
  }
}
