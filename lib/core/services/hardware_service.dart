import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

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
    } else if (Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      return {
        'model': info.prettyName,
        'os': '${info.name} ${info.version ?? info.versionId ?? ""}',
        'cores': Platform.numberOfProcessors,
        'machine': info.machineId ?? 'unknown',
      };
    }
    return {'cores': Platform.numberOfProcessors};
  }

  /// Detect the GPU type on Windows using PowerShell.
  ///
  /// Returns 'nvidia', 'amd', 'intel', or null if unknown.
  Future<String?> _detectGpuTypeWindows() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance -ClassName Win32_VideoController | Select-Object -ExpandProperty Name',
      ]);

      if (result.exitCode == 0) {
        final gpuName = result.stdout.toString().toLowerCase();
        if (gpuName.contains('nvidia')) {
          return 'nvidia';
        } else if (gpuName.contains('amd') || gpuName.contains('radeon')) {
          return 'amd';
        } else if (gpuName.contains('intel')) {
          return 'intel';
        }
      }
    } catch (e) {
      // PowerShell command failed, fallback to FFmpeg detection
    }
    return null;
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
      // First, detect GPU type using PowerShell
      final gpuType = await _detectGpuTypeWindows();

      // Map GPU type to encoder
      if (gpuType == 'nvidia') {
        return 'h264_nvenc';
      } else if (gpuType == 'amd') {
        return 'h264_amf';
      } else if (gpuType == 'intel') {
        return 'h264_qsv';
      }

      // Fallback: check FFmpeg's reported encoders if GPU detection failed
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

    if (Platform.isLinux) {
      // On Linux, check FFmpeg for available hardware encoders
      try {
        final result = await Process.run('ffmpeg', ['-encoders']);
        final output = result.stdout.toString();

        // Check for hardware encoders in order of preference
        if (output.contains('h264_nvenc')) return 'h264_nvenc'; // NVIDIA
        if (output.contains('h264_vaapi'))
          return 'h264_vaapi'; // VA-API (Intel/AMD)
        if (output.contains('h264_qsv')) return 'h264_qsv'; // Intel Quick Sync
        if (output.contains('h264_v4l2m2m'))
          return 'h264_v4l2m2m'; // V4L2 (embedded)
      } catch (e) {
        // FFmpeg not found in PATH
      }
    }

    return null; // Fallback to CPU (libx264)
  }

  /// Get list of available GPU/encoder options for manual selection.
  ///
  /// Returns a map of encoder names to their display names.
  Map<String, String> getEncoderOptions() {
    if (Platform.isWindows) {
      return {
        'h264_nvenc': 'NVIDIA NVENC',
        'h264_amf': 'AMD AMF',
        'h264_qsv': 'Intel Quick Sync',
        'libx264': 'Software (CPU)',
      };
    } else if (Platform.isLinux) {
      return {
        'h264_nvenc': 'NVIDIA NVENC',
        'h264_vaapi': 'VA-API (Intel/AMD)',
        'h264_qsv': 'Intel Quick Sync',
        'h264_v4l2m2m': 'V4L2 (Hardware)',
        'libx264': 'Software (CPU)',
      };
    }
    return {
      'h264_videotoolbox': 'VideoToolbox (macOS)',
      'libx264': 'Software (CPU)',
    };
  }
}
