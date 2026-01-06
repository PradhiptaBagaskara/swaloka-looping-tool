import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/system_info_service.dart';
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
  String? _title;
  String? _author;
  String? _comment;
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
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFF333333))),
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
                  _buildMediaItem(
                    context,
                    _backgroundVideo!,
                    Icons.videocam,
                    isVideo: true,
                    onRemove: () => setState(() => _backgroundVideo = null),
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
                          color: Colors.grey[500],
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
                  // Audio list
                  for (int i = 0; i < _audioFiles.length; i++)
                    _buildMediaItem(
                      context,
                      _audioFiles[i],
                      Icons.music_note,
                      onRemove: () {
                        setState(() {
                          _audioFiles = List<String>.from(_audioFiles)
                            ..removeAt(i);
                        });
                      },
                      index: i + 1,
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
                'Video Metadata (Optional)',
                Icons.settings_suggest_outlined,
              ),
              if (!collapsedSections.contains('Video Metadata (Optional)')) ...[
                const SizedBox(height: 16),
                _buildProjectSettingsInputs(context, ref),
              ],
              const SizedBox(height: 24),
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
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parallel Processing',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Simultaneous encoding tasks',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SettingsNumberInput(
                          initialValue: widget.project.concurrencyLimit
                              .toString(),
                          onChanged: (value) {
                            final intValue = int.tryParse(value);
                            if (intValue != null && intValue > 0) {
                              ref
                                  .read(activeProjectProvider.notifier)
                                  .updateSettings(concurrencyLimit: intValue);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.blue[300],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${SystemInfoService.getCpuInfo()}. Higher values speed up processing but increase CPU usage.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[200],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loop Audio Sequence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Repeat count for audio playlist',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                    disabledForegroundColor: Colors.grey.withValues(alpha: 0.5),
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
    if (!isCollapsible) {
      return Row(
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple[200]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
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
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.deepPurple.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCollapsed
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Colors.deepPurple.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: Colors.deepPurple[200]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (action != null) ...[action, const SizedBox(width: 8)],
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCollapsed
                      ? Colors.grey.withValues(alpha: 0.1)
                      : Colors.deepPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isCollapsed ? Icons.expand_more : Icons.expand_less,
                  size: 18,
                  color: isCollapsed
                      ? Colors.grey[500]
                      : Colors.deepPurple[300],
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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info hint about processing time
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[300]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Adding an intro video will increase processing time',
                    style: TextStyle(fontSize: 11, color: Colors.blue[200]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Intro Audio',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return SegmentedButton<IntroAudioMode>(
                segments: const [
                  ButtonSegment(
                    value: IntroAudioMode.keepOriginal,
                    label: Text('Keep Original'),
                    icon: Icon(Icons.volume_up),
                  ),
                  ButtonSegment(
                    value: IntroAudioMode.silent,
                    label: Text('Mute Intro'),
                    icon: Icon(Icons.volume_off),
                  ),
                  ButtonSegment(
                    value: IntroAudioMode.overlayPlaylist,
                    label: Text('Overlay Playlist'),
                    icon: Icon(Icons.queue_music),
                  ),
                ],
                selected: {widget.project.introAudioMode},
                onSelectionChanged: (Set<IntroAudioMode> newSelection) {
                  ref
                      .read(activeProjectProvider.notifier)
                      .updateSettings(introAudioMode: newSelection.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getIntroAudioDescription(widget.project.introAudioMode),
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFF333333)),
          const SizedBox(height: 16),
          if (_introVideo != null)
            _buildMediaItem(
              context,
              _introVideo!,
              Icons.videocam,
              isVideo: true,
              onRemove: () => setState(() => _introVideo = null),
            )
          else
            _buildDropZone(context, ref, isVideo: true, isIntro: true),
        ],
      ),
    );
  }

  String _getIntroAudioDescription(IntroAudioMode mode) {
    switch (mode) {
      case IntroAudioMode.keepOriginal:
        return 'Play audio from the intro video';
      case IntroAudioMode.silent:
        return 'Intro video plays in silence';
      case IntroAudioMode.overlayPlaylist:
        return 'Play main audio playlist during intro';
    }
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

  Widget _buildProjectSettingsInputs(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.blue[300]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These details will be embedded into the video metadata.',
                    style: TextStyle(fontSize: 10, color: Colors.blue[200]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Video Title',
            hint: 'e.g., Relaxing Music Mix',
            initialValue: _title,
            onChanged: (v) => setState(() => _title = v),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Creator / Channel Name',
            hint: 'e.g., Your Channel Name',
            initialValue: _author,
            onChanged: (v) => setState(() => _author = v),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Comment',
            hint: 'e.g., Made with Swaloka',
            initialValue: _comment,
            onChanged: (v) => setState(() => _comment = v),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    String? initialValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
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
    required VoidCallback onRemove,
    bool isVideo = false,
    int? index,
  }) {
    final fileName = p.basename(path);

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
              border: Border.all(
                color: isVideo
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.green.withValues(alpha: 0.3),
                width: 0.5,
              ),
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

  Widget _buildIssueRow(String label, String introVal, String bgVal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Intro',
                        style: TextStyle(fontSize: 9, color: Colors.red),
                      ),
                      Text(
                        introVal,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
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
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            codec.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Text('Codec Mismatch', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The intro video and background video have different codecs. This may cause issues during merging.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildCodecInfo('Intro Video', introMeta.codec!),
                const SizedBox(height: 8),
                _buildCodecInfo('Background Video', bgMeta.codec!),
                const SizedBox(height: 16),
                const Text(
                  'Recommendation:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please convert your intro video to match the background video codec (e.g., using HandBrake to convert both to H.264/MP4).',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
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
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Text(
                  'Potential Glitch Detected',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The intro video and background video have mismatched properties. This will likely cause the merged video to glitch or fail.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...issues,
                const SizedBox(height: 16),
                const Text(
                  'It is recommended to manually convert your intro video to match the background video parameters before merging.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Process Anyway
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
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
      final sanitizedTitle = (_title ?? 'video').replaceAll(
        RegExp(r'[^a-zA-Z0-9\s]'),
        '',
      );
      final loopPrefix = _audioLoopCount > 1 ? 'loop_${_audioLoopCount}x_' : '';
      final outputFileName =
          '${sanitizedTitle.replaceAll(' ', '_')}_$loopPrefix$timestamp.mp4';
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
        title: _title,
        author: _author,
        comment: _comment,
        concurrencyLimit: widget.project.concurrencyLimit,
        audioLoopCount: _audioLoopCount,
        introVideoPath: _introVideo,
        introAudioMode: widget.project.introAudioMode,
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
