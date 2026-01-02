import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Global logger instance - use this throughout the app
/// Usage: log.i('info'), log.w('warning'), log.e('error'), log.d('debug')
final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // Number of method calls to be displayed
    errorMethodCount: 5, // Number of method calls if stacktrace is provided
    lineLength: 80, // Width of the output
  ),
);

/// Global app logger initialization and error handling
class AppLogger {
  static bool _initialized = false;

  /// Initialize the global app logger with error handlers
  static void initialize() {
    if (_initialized) return;

    // Set up Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      log.e(
        'Flutter Error',
        error: details.exception,
        stackTrace: details.stack,
      );
      // Also call default error handler for crash reporting
      FlutterError.presentError(details);
    };

    // Set up platform error handler (for async errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      log.e('Platform Error', error: error, stackTrace: stack);
      return true; // Mark error as handled
    };

    // Log app initialization
    log.i('🚀 Swaloka Looping Tool initialized');

    _initialized = true;
  }
}
