import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swaloka_looping_tool/core/services/system_info_service.dart';
import 'package:swaloka_looping_tool/core/services/app_logger.dart';

/// State notifier to track FFmpeg status (manual check only, no auto-check on startup)
class FFmpegStatusNotifier extends Notifier<bool?> {
  @override
  bool? build() => null; // null = not checked, true = available, false = not available

  void setStatus(bool status) {
    state = status;
  }

  /// Check FFmpeg and update status (call this explicitly, not on startup)
  Future<bool> checkFFmpeg() async {
    try {
      log.i('🎬 Manually checking FFmpeg installation...');
      final isAvailable = await SystemInfoService.isFFmpegAvailable();
      state = isAvailable;

      if (isAvailable) {
        log.i('✅ FFmpeg found and available');
      } else {
        log.w('⚠️  FFmpeg not found or not in PATH');
      }
      return isAvailable;
    } catch (e, stack) {
      log.e('⚠️  FFmpeg check failed', error: e, stackTrace: stack);
      state = false;
      return false;
    }
  }
}

final ffmpegStatusProvider = NotifierProvider<FFmpegStatusNotifier, bool?>(
  FFmpegStatusNotifier.new,
);

/// Provider to get app version
final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = 'v${packageInfo.version}';
  log.i('📦 App version: $version');
  return version;
});
