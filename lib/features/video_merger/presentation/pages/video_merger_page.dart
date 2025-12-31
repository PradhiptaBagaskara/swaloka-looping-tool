import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/video_merger_providers.dart';
import 'project_landing_page.dart';
import 'video_editor_page.dart';

// Re-export for backwards compatibility
export 'ffmpeg_error_page.dart';
export 'project_landing_page.dart';
export 'video_editor_page.dart';
export '../providers/ffmpeg_provider.dart';

/// Main router page that shows either landing or editor based on project state
class VideoMergerPage extends ConsumerWidget {
  const VideoMergerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider);

    // No project loaded -> show landing page
    if (project == null) {
      return const ProjectLandingPage();
    }


    // Project loaded -> show editor
    return VideoEditorPage(project: project);
  }
}
