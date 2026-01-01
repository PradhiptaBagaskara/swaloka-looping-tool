import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:swaloka_looping_tool/core/services/system_info_service.dart';
import 'package:swaloka_looping_tool/core/utils/log_formatter.dart';
import '../../domain/models/swaloka_project.dart';
import '../providers/video_merger_providers.dart';
import '../providers/ffmpeg_provider.dart';
import '../state/processing_state.dart';
import '../widgets/drop_zone_widget.dart';
import '../widgets/media_preview_player.dart';
import '../widgets/merge_progress_dialog.dart';

/// Supported file extensions
const _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'];
const _audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];

/// Main video editor page with sidebar and timeline
class VideoEditorPage extends ConsumerWidget {
  final SwalokaProject project;

  const VideoEditorPage({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processingState = ref.watch(processingStateProvider);
    final projectFiles = ref.watch(projectFilesProvider);

    final canMerge =
        project.backgroundVideo != null &&
        project.audioFiles.isNotEmpty &&
        project.title != null &&
        project.title!.isNotEmpty &&
        project.author != null &&
        project.author!.isNotEmpty &&
        !processingState.isProcessing;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar
                _buildSidebar(
                  context,
                  ref,
                  processingState,
                  projectFiles,
                  canMerge,
                ),
                // Main Area
                Expanded(
                  child: Column(
                    children: [
                      _buildMainHeader(context),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFF0F0F0F),
                          child: _buildTimelineView(context, ref),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    WidgetRef ref,
    ProcessingState processingState,
    List<FileSystemEntity> projectFiles,
    bool canMerge,
  ) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(right: BorderSide(color: Color(0xFF333333))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(context, ref),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildSectionTitle(context, 'Current Project'),
                const SizedBox(height: 12),
                _buildProjectInfo(context),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Quick Actions'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: canMerge ? () => _mergeVideos(context, ref) : null,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Generate Video'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(activeProjectProvider.notifier).closeProject(),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Close Project'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                if (processingState.isProcessing) ...[
                  const SizedBox(height: 24),
                  _buildProcessingStatus(context, processingState),
                ],
                if (processingState.error != null) ...[
                  const SizedBox(height: 24),
                  _buildErrorMessage(context, processingState.error!),
                ],
                const SizedBox(height: 32),
                if (projectFiles.isNotEmpty) ...[
                  _buildSectionTitle(context, 'Generated Videos'),
                  const SizedBox(height: 12),
                  ...projectFiles
                      .take(5)
                      .map((file) => _buildRecentFileItem(context, file)),
                ],
              ],
            ),
          ),
          _buildSidebarFooter(context),
        ],
      ),
    );
  }

  Widget _buildProjectInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            project.rootPath,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, WidgetRef ref) {
    final appVersion = ref.watch(appVersionProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.movie_filter,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SWALOKA',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'LOOPING TOOL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              appVersion.when(
                data: (version) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    version,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey[600],
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            project.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 8),
          Text('/', style: TextStyle(color: Colors.grey[800], fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              project.rootPath,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const VerticalDivider(
            indent: 12,
            endIndent: 12,
            width: 32,
            color: Colors.white10,
          ),
          TextButton.icon(
            onPressed: () => _showDonateDialog(context),
            icon: const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            label: const Text(
              'Support Us',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(BuildContext context, WidgetRef ref) {
    final collapsedSections = ref.watch(collapsedSectionsProvider);

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildTimelineHeader(
          context,
          ref,
          'PROJECT SETTINGS & METADATA (Required)',
          Icons.settings_suggest_outlined,
        ),
        if (!collapsedSections.contains(
          'PROJECT SETTINGS & METADATA (Required)',
        )) ...[
          const SizedBox(height: 12),
          _buildProjectSettingsInputs(context, ref),
        ],
        const SizedBox(height: 32),
        _buildTimelineHeader(
          context,
          ref,
          'ADVANCED ENCODING SETTINGS',
          Icons.tune,
        ),
        if (!collapsedSections.contains('ADVANCED ENCODING SETTINGS')) ...[
          const SizedBox(height: 12),
          _buildAdvancedEncodingSettings(context, ref),
        ],
        const SizedBox(height: 48),
        _buildTimelineHeader(
          context,
          ref,
          'Background Video',
          Icons.movie_outlined,
        ),
        if (!collapsedSections.contains('Background Video')) ...[
          const SizedBox(height: 12),
          if (project.backgroundVideo != null)
            _buildMediaItem(
              context,
              project.backgroundVideo!,
              Icons.videocam,
              isVideo: true,
              onRemove: () => ref
                  .read(activeProjectProvider.notifier)
                  .setBackgroundVideo(null),
            )
          else
            _buildDropZone(context, ref, isVideo: true),
        ],
        const SizedBox(height: 32),
        _buildTimelineHeader(
          context,
          ref,
          'Audio Tracks (${project.audioFiles.length})',
          Icons.audiotrack,
          action: project.audioFiles.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    ref.read(activeProjectProvider.notifier).removeAllAudios();
                  },
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  tooltip: 'Remove all audio tracks',
                  color: Colors.grey[500],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                )
              : null,
        ),
        if (!collapsedSections.contains(
          'Audio Tracks (${project.audioFiles.length})',
        )) ...[
          const SizedBox(height: 12),
          _buildDropZone(context, ref, isVideo: false),
          // Audio list
          for (int i = 0; i < project.audioFiles.length; i++)
            _buildMediaItem(
              context,
              project.audioFiles[i],
              Icons.music_note,
              onRemove: () {
                final updated = List<String>.from(project.audioFiles)
                  ..removeAt(i);
                ref.read(activeProjectProvider.notifier).setAudioFiles(updated);
              },
              index: i + 1,
            ),
        ],
      ],
    );
  }

  Widget _buildTimelineHeader(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon, {
    Widget? action,
  }) {
    final collapsedSections = ref.watch(collapsedSectionsProvider);
    final isCollapsed = collapsedSections.contains(title);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () =>
                  ref.read(collapsedSectionsProvider.notifier).toggle(title),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.deepPurple[200]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Icon(
                    isCollapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }

  Widget _buildDropZone(
    BuildContext context,
    WidgetRef ref, {
    required bool isVideo,
  }) {
    return DropZoneWidget(
      label: isVideo
          ? 'Add your background video (drag & drop or click)'
          : 'Add audio files (drag & drop or click to select multiple)',
      icon: isVideo
          ? Icons.video_library_outlined
          : Icons.library_music_outlined,
      onFilesDropped: (files) {
        if (isVideo) {
          final videoFile = files.firstWhere(
            (f) =>
                _videoExtensions.contains(f.path.split('.').last.toLowerCase()),
            orElse: () => files.first,
          );
          ref
              .read(activeProjectProvider.notifier)
              .setBackgroundVideo(videoFile.path);
        } else {
          final audioFiles = files
              .where(
                (f) => _audioExtensions.contains(
                  f.path.split('.').last.toLowerCase(),
                ),
              )
              .map((f) => f.path)
              .toList();
          final current = List<String>.from(project.audioFiles);
          current.addAll(audioFiles);
          ref.read(activeProjectProvider.notifier).setAudioFiles(current);
        }
        ref.read(processingStateProvider.notifier).reset();
      },
      onTap: () => isVideo
          ? _selectBackgroundVideo(context, ref)
          : _selectAudioFiles(context, ref),
    );
  }

  Widget _buildAdvancedEncodingSettings(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parallel Processing Cores',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommended: ${SystemInfoService.getRecommendedConcurrency()}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: project.concurrencyLimit.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    if (intValue != null && intValue > 0) {
                      ref
                          .read(activeProjectProvider.notifier)
                          .updateSettings(concurrencyLimit: intValue);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Number of Times to Loop Audios',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How many times to repeat your audio sequence. Audio order shuffles after first loop.',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: project.audioLoopCount.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '1 (minimum)',
                    hintStyle: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    if (intValue != null && intValue >= 1) {
                      ref
                          .read(activeProjectProvider.notifier)
                          .updateSettings(audioLoopCount: intValue);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.customOutputPath ??
                          'Default: ${project.rootPath}/output',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _selectCustomOutput(context, ref),
                icon: const Icon(Icons.folder_open, size: 14),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple[200],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSettingsInputs(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'Video Title *',
            hint: 'e.g., Relaxing Music Mix',
            initialValue: project.title,
            onChanged: (v) => ref
                .read(activeProjectProvider.notifier)
                .updateSettings(title: v),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Creator / Channel Name *',
            hint: 'e.g., Your Channel Name',
            initialValue: project.author,
            onChanged: (v) => ref
                .read(activeProjectProvider.notifier)
                .updateSettings(author: v),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Comment (Optional)',
            hint: 'e.g., Made with Swaloka',
            initialValue: project.comment,
            onChanged: (v) => ref
                .read(activeProjectProvider.notifier)
                .updateSettings(comment: v),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    String? initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[700]),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildMediaItem(
    BuildContext context,
    String path,
    IconData icon, {
    bool isVideo = false,
    required VoidCallback onRemove,
    int? index,
  }) {
    final fileName = path.split('/').last;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
          // Show index number for audio files
          if (index != null) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.deepPurple[200],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isVideo
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isVideo ? Colors.blue[300] : Colors.green[300],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isVideo ? 'Video' : 'Audio',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Preview button for both video and audio
          IconButton(
            icon: Icon(
              Icons.play_circle_outline,
              size: 20,
              color: Colors.grey[500],
            ),
            onPressed: () => _showPreview(context, path, isVideo: isVideo),
            tooltip: 'Preview',
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStatus(BuildContext context, ProcessingState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.deepPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Processing...',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (state.progress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation(Colors.deepPurple),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF333333))),
      ),
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () => _showDonateDialog(context),
            icon: const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            label: const Text(
              'Support Development',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made with ❤️ by Swaloka',
            style: TextStyle(fontSize: 9, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFileItem(BuildContext context, FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final uri = Uri.file(file.parent.path);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Row(
            children: [
              const Icon(Icons.movie_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, String path, {bool isVideo = true}) {
    final fileName = path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isVideo ? 800 : 400,
            maxHeight: isVideo ? 600 : 200,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF333333))),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam : Icons.audiotrack,
                      color: isVideo ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: MediaPreviewPlayer(path: path, isVideo: isVideo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('Support Development', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you find this tool useful, consider supporting its development!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildDonateOption(
              Icons.code,
              'GitHub Sponsors',
              'Support on GitHub',
              () async {
                final url = Uri.parse(
                  'https://github.com/sponsors/AliAkberAakworked',
                );
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            ),
            const SizedBox(height: 12),
            _buildDonateOption(
              Icons.coffee,
              'Buy Me a Coffee',
              'One-time donation',
              () async {
                final url = Uri.parse('https://buymeacoffee.com/swaloka');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDonateOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple[200]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBackgroundVideo(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        initialDirectory: project.rootPath,
      );
      if (result != null && result.files.single.path != null) {
        ref
            .read(activeProjectProvider.notifier)
            .setBackgroundVideo(result.files.single.path!);
        ref.read(processingStateProvider.notifier).reset();
      }
    } catch (e) {
      ref.read(processingStateProvider.notifier).setError('Error: $e');
    }
  }

  Future<void> _selectAudioFiles(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        allowMultiple: true,
        initialDirectory: project.rootPath,
      );
      if (result != null && result.paths.isNotEmpty) {
        final selectedFiles = result.paths
            .where((p) => p != null)
            .cast<String>()
            .toList();
        final current = List<String>.from(project.audioFiles);
        current.addAll(selectedFiles);
        ref.read(activeProjectProvider.notifier).setAudioFiles(current);
        ref.read(processingStateProvider.notifier).reset();
      }
    } catch (e) {
      ref.read(processingStateProvider.notifier).setError('Error: $e');
    }
  }

  Future<void> _selectCustomOutput(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      ref
          .read(activeProjectProvider.notifier)
          .updateSettings(customOutputPath: result);
    }
  }

  Future<void> _mergeVideos(BuildContext context, WidgetRef ref) async {
    final backgroundVideo = project.backgroundVideo;
    final audioFiles = project.audioFiles;
    final outputDir = project.effectiveOutputPath;

    if (backgroundVideo == null || audioFiles.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MergeProgressDialog(),
    );

    String? logFilePath;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedTitle = (project.title ?? 'video').replaceAll(
        RegExp(r'[^a-zA-Z0-9\s]'),
        '',
      );
      final loopPrefix = project.audioLoopCount > 1
          ? 'loop_${project.audioLoopCount}x_'
          : '';
      final outputFileName =
          '${sanitizedTitle.replaceAll(' ', '_')}_$loopPrefix$timestamp.mp4';
      final outputPath = p.join(outputDir, outputFileName);
      logFilePath = p.join(
        project.rootPath,
        'logs',
        'ffmpeg_log_$timestamp.log',
      );

      ref.read(processingStateProvider.notifier).startProcessing();
      final service = ref.read(videoMergerServiceProvider);

      await service.processVideoWithAudio(
        backgroundVideoPath: backgroundVideo,
        audioFiles: audioFiles,
        outputPath: outputPath,
        projectRootPath: project.rootPath,
        title: project.title,
        author: project.author,
        comment: project.comment,
        concurrencyLimit: project.concurrencyLimit,
        audioLoopCount: project.audioLoopCount,
        onProgress: (p) =>
            ref.read(processingStateProvider.notifier).updateProgress(p),
        onLog: (log) => ref.read(processingStateProvider.notifier).addLog(log),
      );

      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
      ref
          .read(projectFilesProvider.notifier)
          .refresh(project.effectiveOutputPath);
    } catch (e) {
      ref.read(processingStateProvider.notifier).setError(e.toString());
    } finally {
      if (logFilePath != null) {
        final logs = ref.read(processingStateProvider).logs;
        if (logs.isNotEmpty) {
          final logFile = File(logFilePath);
          final logLines = LogFormatter.formatLogEntries(logs);
          await logFile.writeAsString(logLines);
        }
      }
    }
  }
}
