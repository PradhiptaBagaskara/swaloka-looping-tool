import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/app_logger.dart';

/// State notifier to track FFmpeg status with auto-check on startup
class FFmpegStatusNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    // Auto-check FFmpeg on startup (async, non-blocking)
    Future.microtask(() => checkFFmpeg());
    return null; // null = checking, true = available, false = not available
  }

  void setStatus(bool status) {
    state = status;
  }

  /// Check FFmpeg and update status
  Future<bool> checkFFmpeg() async {
    try {
      log.i('🎬 Checking FFmpeg installation...');
      final isAvailable = await FFmpegService.isAvailable();
      state = isAvailable;

      if (isAvailable) {
        final path = FFmpegService.ffmpegPath;
        log.i('✅ FFmpeg found: $path');
      } else {
        log.w('⚠️  FFmpeg not found');
      }
      return isAvailable;
    } catch (e, stack) {
      log.e('⚠️  FFmpeg check failed', error: e, stackTrace: stack);
      state = false;
      return false;
    }
  }

  /// Force re-check FFmpeg (e.g., after user installs it)
  Future<bool> recheckFFmpeg() async {
    state = null; // Reset to "checking" state
    FFmpegService.resetCache(); // Clear cached path to re-detect
    return checkFFmpeg();
  }
}

final ffmpegStatusProvider = NotifierProvider<FFmpegStatusNotifier, bool?>(
  FFmpegStatusNotifier.new,
);

/// Provider to get app version
final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = 'v${packageInfo.version}+${packageInfo.buildNumber}';
  log.i('📦 App version: $version');
  return version;
});
