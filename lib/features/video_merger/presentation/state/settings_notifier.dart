import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swaloka_looping_tool/core/services/app_logger.dart';
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';

/// Keys for settings stored in SharedPreferences
class SettingsKeys {
  static const String ffmpegPath = 'ffmpeg_path';
  static const String hwAccelEncoder = 'hwaccel_encoder';
}

/// Hardware acceleration encoder options
enum HwAccelEncoder {
  // Windows Encoders
  nvenc('h264_nvenc', 'NVIDIA (GTX/RTX)'),
  amf('h264_amf', 'AMD Radeon (RX Series)'),
  qsv('h264_qsv', 'Intel QuickSync (iGPU/Arc)'),
  mf('h264_mf', 'Windows Media Foundation'),

  // macOS Encoders
  videotoolbox('h264_videotoolbox', 'Apple Silicon (M1/M2/M3) & Intel Mac'),

  // Linux Encoders
  nvencLinux('h264_nvenc', 'NVIDIA (Proprietary Driver)'),
  vaapi('h264_vaapi', 'VA-API (Intel/AMD)'),
  v4l2m2m('h264_v4l2m2m', 'V4L2 (Raspberry Pi / ARM)'),

  // Software Fallback
  software('libx264', 'Software (CPU)')
  ;

  const HwAccelEncoder(this.value, this.label);

  final String value;
  final String label;

  static HwAccelEncoder fromString(String? value) {
    return HwAccelEncoder.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HwAccelEncoder.software,
    );
  }
}

/// Settings state containing user preferences
class SettingsState {
  const SettingsState({
    this.customFfmpegPath,
    this.hwAccelEncoder = HwAccelEncoder.software,
  });

  /// Custom FFmpeg path set by user (null = auto-detect)
  final String? customFfmpegPath;

  /// Hardware acceleration encoder preference
  final HwAccelEncoder hwAccelEncoder;

  /// Whether user has set a custom FFmpeg path
  bool get hasCustomFfmpegPath =>
      customFfmpegPath != null && customFfmpegPath!.isNotEmpty;

  SettingsState copyWith({
    String? customFfmpegPath,
    bool clearFfmpegPath = false,
    HwAccelEncoder? hwAccelEncoder,
  }) {
    return SettingsState(
      customFfmpegPath: clearFfmpegPath
          ? null
          : customFfmpegPath ?? this.customFfmpegPath,
      hwAccelEncoder: hwAccelEncoder ?? this.hwAccelEncoder,
    );
  }
}

/// Notifier for managing app settings
class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    return _loadSettings();
  }

  Future<SettingsState> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ffmpegPath = prefs.getString(SettingsKeys.ffmpegPath);
      final hwAccelEncoderStr = prefs.getString(SettingsKeys.hwAccelEncoder);
      final hwAccelEncoder = HwAccelEncoder.fromString(hwAccelEncoderStr);

      // If custom path is set, apply it to FFmpegService
      if (ffmpegPath != null && ffmpegPath.isNotEmpty) {
        FFmpegService.setCustomPath(ffmpegPath);
        log.i('⚙️ Loaded custom FFmpeg path: $ffmpegPath');
      }

      // Apply hwaccel encoder setting to FFmpegService
      FFmpegService.setHwAccelEncoder(hwAccelEncoder.value);
      log.i('⚙️ Loaded hwaccel encoder: ${hwAccelEncoder.label}');

      return SettingsState(
        customFfmpegPath: ffmpegPath,
        hwAccelEncoder: hwAccelEncoder,
      );
    } on Exception catch (e) {
      log.e('Failed to load settings', error: e);
      return const SettingsState();
    }
  }

  /// Set custom FFmpeg path
  Future<void> setFfmpegPath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (path == null || path.isEmpty) {
        // Clear custom path, revert to auto-detect
        await prefs.remove(SettingsKeys.ffmpegPath);
        FFmpegService.clearCustomPath();
        log.i('⚙️ Cleared custom FFmpeg path, using auto-detect');
        state = AsyncData(state.value!.copyWith(clearFfmpegPath: true));
      } else {
        // Set custom path
        await prefs.setString(SettingsKeys.ffmpegPath, path);
        FFmpegService.setCustomPath(path);
        log.i('⚙️ Set custom FFmpeg path: $path');
        state = AsyncData(state.value!.copyWith(customFfmpegPath: path));
      }
    } on Exception catch (e) {
      log.e('Failed to save FFmpeg path', error: e);
      rethrow;
    }
  }

  /// Validate a FFmpeg path by checking if it exists and is executable
  Future<bool> validateFfmpegPath(String path) async {
    return FFmpegService.validatePath(path);
  }

  /// Set hardware acceleration encoder preference
  Future<void> setHwAccelEncoder(HwAccelEncoder encoder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SettingsKeys.hwAccelEncoder, encoder.value);
      FFmpegService.setHwAccelEncoder(encoder.value);
      log.i('⚙️ Set hwaccel encoder: ${encoder.label}');
      state = AsyncData(state.value!.copyWith(hwAccelEncoder: encoder));
    } on Exception catch (e) {
      log.e('Failed to save hwaccel encoder', error: e);
      rethrow;
    }
  }
}

/// Provider for app settings
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
