import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/core/theme/app_theme.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/pages/video_merger_page.dart';

class SwalokaApp extends ConsumerWidget {
  const SwalokaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Swaloka Looping Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const VideoMergerPage(),
    );
  }
}
