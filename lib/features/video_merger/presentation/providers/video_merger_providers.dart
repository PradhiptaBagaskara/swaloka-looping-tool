import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/swaloka_project.dart';
import '../../domain/video_merger_service.dart';
import '../state/active_project_notifier.dart';
import '../state/collapsed_sections_notifier.dart';
import '../state/processing_state.dart';
import '../state/processing_state_notifier.dart';
import '../state/project_files_notifier.dart';
import '../state/recent_projects_notifier.dart';

/// Provider for VideoMergerService
final videoMergerServiceProvider = Provider<VideoMergerService>(
  (ref) => VideoMergerService(),
);

/// Provider for active project state
final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, SwalokaProject?>(
      () => ActiveProjectNotifier(),
    );

/// Provider for project files list
final projectFilesProvider =
    NotifierProvider<ProjectFilesNotifier, List<FileSystemEntity>>(
      () => ProjectFilesNotifier(),
    );

/// Provider for processing state
final processingStateProvider =
    NotifierProvider<ProcessingStateNotifier, ProcessingState>(
      () => ProcessingStateNotifier(),
    );

/// Provider for collapsed sections
final collapsedSectionsProvider =
    NotifierProvider<CollapsedSectionsNotifier, Set<String>>(
      () => CollapsedSectionsNotifier(),
    );

/// Provider for recent projects
final recentProjectsProvider =
    NotifierProvider<RecentProjectsNotifier, List<String>>(
      () => RecentProjectsNotifier(),
    );
