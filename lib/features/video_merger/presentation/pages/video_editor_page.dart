import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/utils/log_formatter.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/layouts/layouts.dart';
import 'package:swaloka_looping_tool/widgets/widgets.dart';

/// Supported file extensions
const _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'];
const _audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];

/// Main video editor page - now just contains looper content
class VideoEditorPage extends ConsumerStatefulWidget {
  const VideoEditorPage({required this.project, super.key});
  final SwalokaProject project;

  @override
  ConsumerState<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends ConsumerState<VideoEditorPage> {
  // Session-only state (not persisted)
  List<String> _audioFiles = [];
  String? _backgroundVideo;
  String? _introVideo;
  int _audioLoopCount = 1;

  @override
  Widget build(BuildContext context) {
    return ProjectLayout(
      project: widget.project,
      looperContent: _buildTimelineView(context, ref),
    );
  }

  Widget _buildTimelineView(BuildContext context, WidgetRef ref) {
    final collapsedSections = ref.watch(collapsedSectionsProvider);
    final processingState = ref.watch(processingStateProvider);

    final canMerge =
        _backgroundVideo != null &&
        _audioFiles.isNotEmpty &&
        !processingState.isProcessing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT PANEL: Media Assets (Videos + Audio)
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader(
                  context,
                  ref,
                  'Intro Video (Optional)',
                  Icons.play_circle_filled,
                ),
                if (!collapsedSections.contains('Intro Video (Optional)')) ...[
                  const SizedBox(height: 16),
                  _buildIntroSection(context, ref),
                ],
                const SizedBox(height: 32),
                _buildSectionHeader(
                  context,
                  ref,
                  'Background Video',
                  Icons.movie_outlined,
                  isCollapsible: false,
                ),
                const SizedBox(height: 16),
                if (_backgroundVideo != null)
                  MediaItemCard(
                    path: _backgroundVideo!,
                    icon: Icons.videocam,
                    isVideo: true,
                    onRemove: () => setState(() => _backgroundVideo = null),
                    onPreview: () => _showPreview(
                      context,
                      _backgroundVideo!,
                    ),
                  )
                else
                  _buildDropZone(context, ref, isVideo: true),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  context,
                  ref,
                  'Audio Tracks (${_audioFiles.length})',
                  Icons.audiotrack,
                  isCollapsible: false,
                  action: _audioFiles.isNotEmpty
                      ? IconButton(
                          onPressed: () => setState(() => _audioFiles = []),
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          tooltip: 'Remove all audio tracks',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                _buildDropZone(context, ref, isVideo: false),
                if (_audioFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // Audio list with drag-and-drop reordering
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _audioFiles.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final files = List<String>.from(_audioFiles);
                        final item = files.removeAt(oldIndex);
                        files.insert(newIndex, item);
                        _audioFiles = files;
                      });
                    },
                    proxyDecorator: (child, index, animation) {
                      final fileName = p.basename(_audioFiles[index]);
                      final t = Curves.easeInOut.transform(animation.value);
                      final elevation = lerpDouble(0, 6, t)!;
                      final scale = lerpDouble(1.0, 1.02, t)!;

                      return Transform.scale(
                        scale: scale,
                        child: Material(
                          elevation: elevation,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.5,
                              minWidth: 300,
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drag_indicator,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiaryContainer,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.music_note,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          fileName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Audio',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Static icons instead of buttons
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context, i) {
                      return ReorderableDragStartListener(
                        key: ValueKey(_audioFiles[i]),
                        index: i,
                        child: MediaItemCard(
                          path: _audioFiles[i],
                          icon: Icons.music_note,
                          onRemove: () {
                            setState(() {
                              _audioFiles = List<String>.from(_audioFiles)
                                ..removeAt(i);
                            });
                          },
                          onPreview: () => _showPreview(
                            context,
                            _audioFiles[i],
                          ),
                          index: i + 1,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // RIGHT PANEL: Settings & Metadata
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionHeader(
                context,
                ref,
                'Processing Settings',
                Icons.tune,
                isCollapsible: false,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  children: [
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Loop Count',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const CompactTooltip(
                                message:
                                    'Repeats the audio playlist.\n\n'
                                    'Useful when video is longer\n'
                                    'than your audio tracks.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SettingsNumberInput(
                          initialValue: _audioLoopCount.toString(),
                          onChanged: (value) {
                            final intValue = int.tryParse(value);
                            if (intValue != null && intValue >= 1) {
                              setState(() => _audioLoopCount = intValue);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canMerge ? () => _mergeVideos(context, ref) : null,
                  icon: const Icon(Icons.auto_fix_high, size: 20),
                  label: const Text(
                    'Generate Video',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    elevation: 4,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon, {
    Widget? action,
    bool isCollapsible = true,
  }) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    if (!isCollapsible) {
      return Row(
        children: [
          Icon(
            icon,
            size: baseFontSize * 1.14,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: baseFontSize * 0.86),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ?action,
        ],
      );
    }

    final collapsedSections = ref.watch(collapsedSectionsProvider);
    final isCollapsed = collapsedSections.contains(title);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => ref.read(collapsedSectionsProvider.notifier).toggle(title),
        borderRadius: BorderRadius.circular(baseFontSize * 0.57),
        hoverColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: baseFontSize * 0.86,
            vertical: baseFontSize * 0.71,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(baseFontSize * 0.57),
            border: Border.all(
              color: isCollapsed
                  ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(baseFontSize * 0.43),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(baseFontSize * 0.43),
                ),
                child: Icon(
                  icon,
                  size: baseFontSize * 1.14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: baseFontSize * 0.86),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (action != null) ...[
                action,
                SizedBox(width: baseFontSize * 0.57),
              ],
              Container(
                padding: EdgeInsets.all(baseFontSize * 0.29),
                decoration: BoxDecoration(
                  color: isCollapsed
                      ? Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(baseFontSize * 0.29),
                ),
                child: Icon(
                  isCollapsed ? Icons.expand_more : Icons.expand_less,
                  size: baseFontSize * 1.29,
                  color: isCollapsed
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSection(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info hint about processing time
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Adding an intro video will increase processing time',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.queue_music,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Intro Audio: Playlist Overlay',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The main audio playlist will play during the intro video',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (_introVideo != null)
            MediaItemCard(
              path: _introVideo!,
              icon: Icons.videocam,
              isVideo: true,
              onRemove: () => setState(() => _introVideo = null),
              onPreview: () => _showPreview(
                context,
                _introVideo!,
              ),
            )
          else
            _buildDropZone(context, ref, isVideo: true, isIntro: true),
        ],
      ),
    );
  }

  Widget _buildDropZone(
    BuildContext context,
    WidgetRef ref, {
    required bool isVideo,
    bool isIntro = false,
  }) {
    String label;
    IconData icon;

    if (isVideo) {
      if (isIntro) {
        label = 'Add optional intro video (drag & drop or click)';
        icon = Icons.play_circle_outline;
      } else {
        label = 'Add your background video (drag & drop or click)';
        icon = Icons.video_library_outlined;
      }
    } else {
      label = 'Add audio files (drag & drop or click to select multiple)';
      icon = Icons.library_music_outlined;
    }

    return DropZoneWidget(
      label: label,
      icon: icon,
      onFilesDropped: (files) {
        if (isVideo) {
          final videoFile = files.firstWhere(
            (f) =>
                _videoExtensions.contains(f.path.split('.').last.toLowerCase()),
            orElse: () => files.first,
          );
          setState(() {
            if (isIntro) {
              _introVideo = videoFile.path;
            } else {
              _backgroundVideo = videoFile.path;
            }
          });
        } else {
          final audioFiles = files
              .where(
                (f) => _audioExtensions.contains(
                  f.path.split('.').last.toLowerCase(),
                ),
              )
              .map((f) => f.path)
              .toList();
          setState(() {
            _audioFiles = List<String>.from(_audioFiles)..addAll(audioFiles);
          });
        }
        ref.read(processingStateProvider.notifier).reset();
      },
      onTap: () => isVideo
          ? _selectVideo(context, ref, isIntro: isIntro)
          : _selectAudioFiles(context, ref),
    );
  }

  void _showPreview(BuildContext context, String path, {bool isVideo = true}) {
    final fileName = p.basename(path);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isVideo ? 800 : 400,
            maxHeight: isVideo ? 600 : 200,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam : Icons.audiotrack,
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _buildIssueRow(String label, String introVal, String bgVal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intro',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      Text(
                        introVal,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(
                      alpha: 0.1,
                    ), // Keep green for success/background
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Background',
                        style: TextStyle(fontSize: 9, color: Colors.green),
                      ),
                      Text(
                        bgVal,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodecInfo(String label, String codec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            codec.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectVideo(
    BuildContext context,
    WidgetRef ref, {
    required bool isIntro,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        initialDirectory: widget.project.rootPath,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          if (isIntro) {
            _introVideo = result.files.single.path;
          } else {
            _backgroundVideo = result.files.single.path;
          }
        });
        ref.read(processingStateProvider.notifier).reset();
      }
    } on Exception catch (e) {
      ref.read(processingStateProvider.notifier).setError('Error: $e');
    }
  }

  Future<void> _selectAudioFiles(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        allowMultiple: true,
        initialDirectory: widget.project.rootPath,
      );
      if (result != null && result.paths.isNotEmpty) {
        final selectedFiles = result.paths
            .where((p) => p != null)
            .cast<String>()
            .toList();
        setState(() {
          _audioFiles = List<String>.from(_audioFiles)..addAll(selectedFiles);
        });
        ref.read(processingStateProvider.notifier).reset();
      }
    } on Exception catch (e) {
      ref.read(processingStateProvider.notifier).setError('Error: $e');
    }
  }

  Future<void> _mergeVideos(BuildContext context, WidgetRef ref) async {
    final backgroundVideo = _backgroundVideo;
    final audioFiles = _audioFiles;
    final outputDir = widget.project.effectiveOutputPath;

    if (backgroundVideo == null || audioFiles.isEmpty) return;

    // Codec Validation (Warning only, can't easily auto-fix cross-codec without massive re-encode)
    if (_introVideo != null) {
      // Get metadata for both videos (cached, so only one ffprobe call per file)
      final introMeta = await FFmpegService.getVideoMetadata(
        _introVideo!,
      );
      final bgMeta = await FFmpegService.getVideoMetadata(backgroundVideo);

      // Check codec mismatch
      if (introMeta.codec != null &&
          bgMeta.codec != null &&
          introMeta.codec != bgMeta.codec) {
        if (!context.mounted) return;
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Text(
                  'Codec Mismatch',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The intro video and background video have different codecs. This may cause issues during merging.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCodecInfo('Intro Video', introMeta.codec!),
                const SizedBox(height: 8),
                _buildCodecInfo('Background Video', bgMeta.codec!),
                const SizedBox(height: 16),
                Text(
                  'Recommendation:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please convert your intro video to match the background video codec (e.g., using HandBrake to convert both to H.264/MP4).',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('I Understand, Try Anyway'),
              ),
            ],
          ),
        );

        if (shouldProceed != true) return;
      }

      // 2. Check Resolution, FPS, and Pixel Format Mismatch
      final issues = <Widget>[];

      // Check Resolution
      if (introMeta.width != null &&
          introMeta.height != null &&
          bgMeta.width != null &&
          bgMeta.height != null) {
        if (introMeta.width != bgMeta.width ||
            introMeta.height != bgMeta.height) {
          issues.add(
            _buildIssueRow(
              'Resolution',
              '${introMeta.width}x${introMeta.height}',
              '${bgMeta.width}x${bgMeta.height}',
            ),
          );
        }
      }

      // Check FPS
      if (introMeta.fps != null &&
          bgMeta.fps != null &&
          introMeta.fps != bgMeta.fps) {
        issues.add(
          _buildIssueRow(
            'Frame Rate',
            '${introMeta.fps} fps',
            '${bgMeta.fps} fps',
          ),
        );
      }

      // Check Pixel Format
      if (introMeta.pixFmt != null &&
          bgMeta.pixFmt != null &&
          introMeta.pixFmt != bgMeta.pixFmt) {
        issues.add(
          _buildIssueRow('Pixel Format', introMeta.pixFmt!, bgMeta.pixFmt!),
        );
      }

      if (issues.isNotEmpty) {
        if (!context.mounted) return;
        // 0: Cancel, 1: Process Anyway
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Text(
                  'Potential Glitch Detected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The intro video and background video have mismatched properties. This will likely cause the merged video to glitch or fail.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...issues,
                const SizedBox(height: 16),
                Text(
                  'It is recommended to manually convert your intro video to match the background video parameters before merging.',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Process Anyway
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Process Anyway'),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          return; // Cancel
        }
      }
    }

    if (!context.mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MergeProgressDialog(),
      ),
    );

    String? logFilePath;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final loopPrefix = _audioLoopCount > 1 ? 'loop_${_audioLoopCount}x_' : '';
      final outputFileName = 'video_$loopPrefix$timestamp.mp4';
      final outputPath = p.join(outputDir, outputFileName);
      logFilePath = p.join(
        widget.project.rootPath,
        'logs',
        'ffmpeg_log_$timestamp.log',
      );

      ref.read(processingStateProvider.notifier).startProcessing();
      final service = ref.read(videoMergerServiceProvider);

      await service.processVideoWithAudio(
        backgroundVideoPath: backgroundVideo,
        audioFiles: audioFiles,
        outputPath: outputPath,
        projectRootPath: widget.project.rootPath,
        audioLoopCount: _audioLoopCount,
        introVideoPath: _introVideo,
        enableParallelProcessing: widget.project.enableParallelProcessing,
        onProgress: (p) =>
            ref.read(processingStateProvider.notifier).updateProgress(p),
        onLog: (log) => ref.read(processingStateProvider.notifier).addLog(log),
      );

      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
      ref
          .read(projectFilesProvider.notifier)
          .refresh(widget.project.effectiveOutputPath);
    } on Exception catch (e) {
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
