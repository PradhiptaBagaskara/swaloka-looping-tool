import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/core/theme/theme.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/pages/video_merger_page.dart';

class SwalokaApp extends ConsumerWidget {
  const SwalokaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // This rebuilds the app with responsive theme when window is resized
        return MaterialApp(
          title: 'Swaloka Looping Tool',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.responsiveLightTheme(context),
          darkTheme: AppTheme.responsiveTheme(context),
          themeMode: themeMode,
          home: const VideoMergerPage(),
        );
      },
    );
  }
}
