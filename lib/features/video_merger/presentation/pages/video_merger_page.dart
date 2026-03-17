import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:swaloka_looping_tool/features/landing_page/landing_page.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/pages/video_editor_page.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/ffmpeg_provider.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/layouts/layouts.dart';

export '../providers/ffmpeg_provider.dart';
export 'video_editor_page.dart';

/// Main router page that shows either FFmpeg error, landing, or editor
class VideoMergerPage extends ConsumerWidget {
  const VideoMergerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);

    // Check FFmpeg first
    if (ffmpegStatus == false) {
      return const LandingLayout(
        child: FFmpegErrorPage(),
      );
    }

    final project = ref.watch(activeProjectProvider);

    // No project loaded -> show landing page with landing layout
    if (project == null) {
      return const LandingLayout(
        child: ProjectLandingPage(),
      );
    }

    // Project loaded -> show editor with project layout
    return VideoEditorPage(project: project);
  }
}
