import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/video_merger_service.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/active_project_notifier.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/collapsed_sections_notifier.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/processing_state.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/processing_state_notifier.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/project_files_notifier.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/recent_projects_notifier.dart';

/// Provider for VideoMergerService
final videoMergerServiceProvider = Provider<VideoMergerService>(
  (ref) => VideoMergerService(),
);

/// Provider for active project state
final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, SwalokaProject?>(
      ActiveProjectNotifier.new,
    );

/// Provider for project files list
final projectFilesProvider =
    NotifierProvider<ProjectFilesNotifier, List<FileSystemEntity>>(
      ProjectFilesNotifier.new,
    );

/// Provider for processing state
final processingStateProvider =
    NotifierProvider<ProcessingStateNotifier, ProcessingState>(
      ProcessingStateNotifier.new,
    );

/// Provider for collapsed sections
final collapsedSectionsProvider =
    NotifierProvider<CollapsedSectionsNotifier, Set<String>>(
      CollapsedSectionsNotifier.new,
    );

/// Provider for recent projects
final recentProjectsProvider =
    NotifierProvider<RecentProjectsNotifier, List<String>>(
      RecentProjectsNotifier.new,
    );
