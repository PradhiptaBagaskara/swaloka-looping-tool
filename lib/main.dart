import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/app.dart';
import 'package:swaloka_looping_tool/core/constants/app_constants.dart';
import 'package:swaloka_looping_tool/core/services/app_logger.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global app logger
  AppLogger.initialize();

  log.i('🎬 Video player ready (using native AVFoundation)');

  // Initialize window manager for desktop platforms
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(
        AppConstants.defaultWindowWidth,
        AppConstants.defaultWindowHeight,
      ),
      minimumSize: Size(
        AppConstants.minWindowWidth,
        AppConstants.minWindowHeight,
      ),
      center: true,
      backgroundColor: Color(0xFF0F0F0F),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Swaloka Looping Tool',
    );

    // Set window properties and show it
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      log.i('🪟 Window shown and focused');
    });
  }

  // Run app with Riverpod for state management
  runApp(const ProviderScope(child: SwalokaApp()));
}
