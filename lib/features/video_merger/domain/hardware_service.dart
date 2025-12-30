import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HardwareInfo {
  final String gpuName;
  final bool isFfmpegInstalled;
  final String? cpuName;
  final String? bestEncoder;
  final String? selectedEncoder; // User-selected encoder for manual override

  HardwareInfo({
    required this.gpuName,
    required this.isFfmpegInstalled,
    this.cpuName,
    this.bestEncoder,
    this.selectedEncoder,
  });

  /// Get the encoder to use (selected encoder if set, otherwise best detected)
  String? get effectiveEncoder => selectedEncoder ?? bestEncoder;
}

class HardwareService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<HardwareInfo> getHardwareInfo() async {
    String gpuName = 'Unknown GPU';
    String? cpuName;
    bool isFfmpegInstalled = false;
    String? bestEncoder;

    try {
      if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        cpuName = windowsInfo.computerName;

        // Better GPU detection on Windows using PowerShell
        try {
          final result = await Process.run('powershell', [
            '-Command',
            'Get-CimInstance -ClassName Win32_VideoController | Select-Object -ExpandProperty Name',
          ]);
          if (result.exitCode == 0) {
            gpuName = result.stdout.toString().trim();
          }
        } catch (_) {}

        try {
          final result = await Process.run('ffmpeg', ['-version']);
          isFfmpegInstalled = result.exitCode == 0;
          if (isFfmpegInstalled) {
            bestEncoder = await _detectBestEncoderWindows();
          }
        } catch (_) {
          isFfmpegInstalled = false;
        }
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        cpuName = macInfo.model;
        gpuName = 'Apple Graphics'; // Generic for macOS/Metal
        isFfmpegInstalled = true;
        bestEncoder = 'h264_videotoolbox';
      }
    } catch (e) {
      // Fallback
    }

    return HardwareInfo(
      gpuName: gpuName,
      isFfmpegInstalled: isFfmpegInstalled,
      cpuName: cpuName,
      bestEncoder: bestEncoder,
    );
  }

  Future<String?> _detectBestEncoderWindows() async {
    try {
      final result = await Process.run('ffmpeg', ['-encoders']);
      final output = result.stdout.toString();
      if (output.contains('h264_nvenc')) return 'h264_nvenc';
      if (output.contains('h264_qsv')) return 'h264_qsv';
      if (output.contains('h264_amf')) return 'h264_amf';
    } catch (_) {}
    return null;
  }

  Future<String?> detectBestEncoder() async {
    final info = await getHardwareInfo();
    return info.bestEncoder;
  }
}

final hardwareServiceProvider = Provider((ref) => HardwareService());

final hardwareInfoProvider = FutureProvider<HardwareInfo>((ref) async {
  return ref.read(hardwareServiceProvider).getHardwareInfo();
});
