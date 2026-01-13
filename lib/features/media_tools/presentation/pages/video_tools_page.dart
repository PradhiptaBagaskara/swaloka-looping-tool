import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/features/media_tools/presentation/providers/media_tools_providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/widgets.dart';

const _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'];

class VideoToolsPage extends ConsumerStatefulWidget {
  const VideoToolsPage({required this.initialDirectory, super.key});
  final String initialDirectory;

  @override
  ConsumerState<VideoToolsPage> createState() => _VideoToolsPageState();
}

class _VideoToolsPageState extends ConsumerState<VideoToolsPage> {
  // Concat Videos State
  final List<String> _videoPaths = [];
  bool _keepAudio = true;
  bool _smoothTransition = false;
  bool _fadeIn = false; // Fade in from color at start
  bool _fadeOut = false; // Fade out to color at end
  Color _fadeInColor = Colors.black; // Fade in color
  Color _fadeOutColor = Colors.black; // Fade out color
  String _encodingPreset = 'veryfast'; // Default to veryfast

  // Compress Video State
  String? _compressVideoPath;
  int _compressCrf = 23; // Default balanced
  String _compressPreset = 'veryfast';
  bool _compressKeepAudio = true;
  bool _useHwAccel = false;
  String _hwAccelEncoder = 'libx264'; // Will be updated in initState

  // Re-encode Video State
  String? _reencodeVideoPath;
  String _reencodeResolution = '1080p'; // 480p, 720p, 1080p, 2K, 4K, 8K
  String _reencodeAspectRatio =
      'original'; // original, 16:9, 9:16, 1:1, 3:2, 2:3
  int _reencodeFps = 30;
  String _reencodePreset = 'veryfast';
  bool _reencodeKeepAudio = true;
  bool _reencodeUseHwAccel = false;
  String _reencodeHwEncoder = 'libx264';
  String? _reencodeReferenceVideoName;

  // Video Info State
  String? _infoVideoPath;
  Map<String, dynamic>? _videoInfo;

  @override
  void initState() {
    super.initState();
    // Set default HW encoder based on Platform
    if (Platform.isMacOS) {
      _hwAccelEncoder = 'h264_videotoolbox';
      _reencodeHwEncoder = 'h264_videotoolbox';
    } else if (Platform.isWindows) {
      _hwAccelEncoder = 'h264_nvenc';
      _reencodeHwEncoder = 'h264_nvenc';
    } else if (Platform.isLinux) {
      _hwAccelEncoder = 'h264_vaapi';
      _reencodeHwEncoder = 'h264_vaapi';
    }
  }

  Future<String> _ensureOutputsDir() async {
    final outputsDir = Directory(p.join(widget.initialDirectory, 'outputs'));
    if (!await outputsDir.exists()) {
      await outputsDir.create(recursive: true);
    }
    return outputsDir.path;
  }

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null) {
      setState(() {
        _videoPaths.addAll(result.paths.whereType<String>().toList());
      });
    }
  }

  Future<void> _pickCompressVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _compressVideoPath = result.files.single.path;
      });
    }
  }

  Future<void> _concatVideos() async {
    if (_videoPaths.isEmpty) return;

    final notifier = ref.read(processingStateProvider.notifier);
    notifier.startProcessing();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MergeProgressDialog(),
      ),
    );

    try {
      final outputsDir = await _ensureOutputsDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final prefix = _videoPaths.length == 1
          ? 'processed_video'
          : 'merged_videos';
      final outputPath = p.join(outputsDir, '${prefix}_$timestamp.mp4');

      await ref
          .read(mediaToolsServiceProvider)
          .concatVideos(
            videoPaths: _videoPaths,
            outputPath: outputPath,
            keepAudio: _keepAudio,
            smoothTransition: _smoothTransition,
            fadeIn: _fadeIn,
            fadeOut: _fadeOut,
            fadeInColor: _colorToHex(_fadeInColor),
            fadeOutColor: _colorToHex(_fadeOutColor),
            encodingPreset: _encodingPreset,
            hwEncoder: _useHwAccel ? _hwAccelEncoder : null,
            onLog: notifier.addLog,
          );

      notifier.setSuccess(outputPath);
    } on Exception catch (e) {
      notifier.setError(e.toString());
    }
  }

  Future<void> _compressVideo() async {
    if (_compressVideoPath == null) return;

    final notifier = ref.read(processingStateProvider.notifier);
    notifier.startProcessing();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MergeProgressDialog(),
      ),
    );

    try {
      final outputsDir = await _ensureOutputsDir();
      final name = p.basenameWithoutExtension(_compressVideoPath!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(
        outputsDir,
        '${name}_compressed_$timestamp.mp4',
      );

      await ref
          .read(mediaToolsServiceProvider)
          .compressVideo(
            videoPath: _compressVideoPath!,
            outputPath: outputPath,
            crf: _compressCrf,
            preset: _compressPreset,
            keepAudio: _compressKeepAudio,
            hwEncoder: _useHwAccel ? _hwAccelEncoder : null,
            onLog: notifier.addLog,
          );

      notifier.setSuccess(outputPath);
    } on Exception catch (e) {
      notifier.setError(e.toString());
    }
  }

  Future<void> _pickReencodeVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _reencodeVideoPath = result.files.single.path;
      });
    }
  }

  Future<void> _copyFormatFromVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.initialDirectory,
    );

    if (result != null && result.files.single.path != null) {
      final videoPath = result.files.single.path!;

      try {
        // Show loading indicator
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing video format...'),
            duration: Duration(seconds: 2),
          ),
        );

        // Get video metadata
        final metadata = await FFmpegService.getVideoMetadata(videoPath);

        if (!mounted) return;

        // Parse FPS (it's a string like "30" or "29.97")
        var fps = 30;
        if (metadata.fps != null) {
          final fpsDouble = double.tryParse(metadata.fps!);
          if (fpsDouble != null) {
            fps = fpsDouble.round();
            // Map to closest available FPS option
            if (fps <= 24) {
              fps = 24;
            } else if (fps <= 25) {
              fps = 25;
            } else if (fps <= 30) {
              fps = 30;
            } else {
              fps = 60;
            }
          }
        }

        // Map video height to closest resolution preset
        var resolution = '1080p'; // Default
        if (metadata.height != null) {
          final height = metadata.height!;
          if (height <= 480) {
            resolution = '480p';
          } else if (height <= 720) {
            resolution = '720p';
          } else if (height <= 1080) {
            resolution = '1080p';
          } else if (height <= 1440) {
            resolution = '2K';
          } else if (height <= 2160) {
            resolution = '4K';
          } else {
            resolution = '8K';
          }
        }

        // Detect aspect ratio from video dimensions
        var aspectRatio = 'original'; // Default to original
        if (metadata.width != null && metadata.height != null) {
          final width = metadata.width!;
          final height = metadata.height!;
          final ratio = width / height;

          // Match to closest common aspect ratio
          if ((ratio - 16 / 9).abs() < 0.05) {
            aspectRatio = '16:9';
          } else if ((ratio - 9 / 16).abs() < 0.05) {
            aspectRatio = '9:16';
          } else if ((ratio - 1).abs() < 0.05) {
            aspectRatio = '1:1';
          } else if ((ratio - 3 / 2).abs() < 0.05) {
            aspectRatio = '3:2';
          } else if ((ratio - 2 / 3).abs() < 0.05) {
            aspectRatio = '2:3';
          } else {
            // If it doesn't match any preset, keep as "original"
            aspectRatio = 'original';
          }
        }

        setState(() {
          _reencodeResolution = resolution;
          _reencodeAspectRatio = aspectRatio;
          _reencodeFps = fps;
          _reencodeReferenceVideoName = p.basename(videoPath);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Format copied: $resolution @ ${fps}fps',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } on Exception catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to analyze video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reencodeVideo() async {
    if (_reencodeVideoPath == null) return;

    final notifier = ref.read(processingStateProvider.notifier);
    notifier.startProcessing();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MergeProgressDialog(),
      ),
    );

    try {
      final outputsDir = await _ensureOutputsDir();
      final name = p.basenameWithoutExtension(_reencodeVideoPath!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Get target height from resolution
      final heightMap = {
        '480p': 480,
        '720p': 720,
        '1080p': 1080,
        '2K': 1440,
        '4K': 2160,
        '8K': 4320,
      };
      final targetHeight = heightMap[_reencodeResolution] ?? 1080;

      // Calculate dimensions based on aspect ratio
      int targetWidth;
      var preserveAspectRatio = false;

      if (_reencodeAspectRatio == 'original') {
        // Get original video dimensions to preserve aspect ratio
        final metadata = await FFmpegService.getVideoMetadata(
          _reencodeVideoPath!,
        );
        if (metadata.width != null && metadata.height != null) {
          final originalAspect = metadata.width! / metadata.height!;
          targetWidth = (targetHeight * originalAspect).round();
          // Ensure even width
          if (targetWidth % 2 != 0) targetWidth++;
        } else {
          // Fallback to 16:9 if metadata unavailable
          targetWidth = (targetHeight * 16 / 9).round();
        }
        preserveAspectRatio = true;
      } else {
        final dimensions = _getResolutionDimensions(
          _reencodeResolution,
          _reencodeAspectRatio,
        );
        if (dimensions != null) {
          targetWidth = dimensions.width;
        } else {
          // Fallback
          targetWidth = (targetHeight * 16 / 9).round();
        }
      }

      final aspectRatioLabel = _reencodeAspectRatio == 'original'
          ? 'original'
          : _reencodeAspectRatio.replaceAll(':', '_');
      final outputPath = p.join(
        outputsDir,
        '${name}_${_reencodeResolution}_${aspectRatioLabel}_${_reencodeFps}fps_$timestamp.mp4',
      );

      await ref
          .read(mediaToolsServiceProvider)
          .reencodeVideo(
            videoPath: _reencodeVideoPath!,
            outputPath: outputPath,
            width: targetWidth,
            height: targetHeight,
            fps: _reencodeFps,
            preset: _reencodePreset,
            keepAudio: _reencodeKeepAudio,
            preserveAspectRatio: preserveAspectRatio,
            hwEncoder: _reencodeUseHwAccel ? _reencodeHwEncoder : null,
            onLog: notifier.addLog,
          );

      notifier.setSuccess(outputPath);
    } on Exception catch (e) {
      notifier.setError(e.toString());
    }
  }

  Future<void> _pickInfoVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _infoVideoPath = result.files.single.path;
        _videoInfo = null; // Reset info when new video selected
      });
      await _extractVideoInfo();
    }
  }

  Future<void> _extractVideoInfo() async {
    if (_infoVideoPath == null) return;

    try {
      final metadata = await FFmpegService.getVideoMetadata(_infoVideoPath!);
      final fileInfo = await File(_infoVideoPath!).stat();

      setState(() {
        _videoInfo = {
          'fileName': p.basename(_infoVideoPath!),
          'filePath': _infoVideoPath,
          'fileSize': fileInfo.size,
          'width': metadata.width,
          'height': metadata.height,
          'fps': metadata.fps,
          'codec': metadata.codec,
          'pixelFormat': metadata.pixFmt,
          'duration': metadata.duration,
          'hasAudio': metadata.hasAudio,
          'metadataTags': metadata.metadataTags,
        };
      });
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to extract video info: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      color: isVideo
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.tertiary,
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

  Widget _buildMediaItem(
    BuildContext context,
    String path,
    IconData icon, {
    required VoidCallback onRemove,
    bool isVideo = true,
    int? index,
  }) {
    final fileName = p.basename(path);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          if (index != null) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
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
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isVideo
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.tertiaryContainer,
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isVideo
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isVideo ? 'Video' : 'Audio',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.play_circle_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showPreview(context, path, isVideo: isVideo),
            tooltip: 'Preview',
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: TabBar(
              tabs: const [
                Tab(
                  text: 'Combine & Effects',
                  icon: Icon(Icons.video_library, size: 20),
                ),
                Tab(
                  text: 'Compress Video',
                  icon: Icon(Icons.compress, size: 20),
                ),
                Tab(
                  text: 'Convert Resolution',
                  icon: Icon(Icons.settings_backup_restore, size: 20),
                ),
                Tab(
                  text: 'Video Info',
                  icon: Icon(Icons.info_outline, size: 20),
                ),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Theme.of(context).colorScheme.outline,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTabContent(_buildConcatContent()),
                _buildTabContent(_buildCompressContent()),
                _buildTabContent(_buildReencodeContent()),
                _buildTabContent(_buildVideoInfoContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(Widget content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildConcatContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropZoneWidget(
          label: _videoPaths.isNotEmpty
              ? '${_videoPaths.length} ${_videoPaths.length == 1 ? "file" : "files"} selected'
              : 'Drop Video File(s) Here (or Click)',
          icon: Icons.movie,
          onTap: _pickVideos,
          onFilesDropped: (files) {
            final videos = files
                .where(
                  (f) => _videoExtensions.contains(
                    p.extension(f.path).replaceAll('.', '').toLowerCase(),
                  ),
                )
                .map((f) => f.path)
                .toList();
            if (videos.isNotEmpty) {
              setState(() {
                _videoPaths.addAll(videos);
              });
            }
          },
        ),
        if (_videoPaths.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => setState(_videoPaths.clear),
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < _videoPaths.length; i++)
                Padding(
                  padding: EdgeInsets.zero,
                  child: _buildMediaItem(
                    context,
                    _videoPaths[i],
                    Icons.movie,
                    index: i + 1,
                    onRemove: () {
                      setState(() {
                        _videoPaths.removeAt(i);
                      });
                    },
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Info box for single video processing
        if (_videoPaths.length == 1) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Single video mode: You can add fade in/out effects. Smooth transitions require 2+ videos.',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Group: Audio & Transitions
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
              CheckboxListTile(
                title: Text(
                  'Keep Audio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Preserves audio tracks in merged video',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: _keepAudio,
                onChanged: (v) => setState(() => _keepAudio = v ?? true),
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).colorScheme.primary,
                dense: true,
              ),
              const Divider(),
              CheckboxListTile(
                title: Text(
                  'Smooth Transition (Crossfade)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  _videoPaths.length <= 1
                      ? 'Requires 2 or more videos'
                      : 'Adds 1s crossfade between clips. Requires re-encoding.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: _smoothTransition,
                onChanged: _videoPaths.length > 1
                    ? (v) => setState(() => _smoothTransition = v ?? false)
                    : null,
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).colorScheme.primary,
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Group: Fade Effects
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fade Effects',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Great for creating loop-friendly videos',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              // Fade In Row
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _fadeIn,
                      onChanged: (v) => setState(() => _fadeIn = v ?? false),
                      activeColor: Theme.of(context).colorScheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fade In',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Fades from color at the start (1s)',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_fadeIn) ...[
                    const SizedBox(width: 8),
                    ColorPickerButton(
                      color: _fadeInColor,
                      onColorChanged: (c) => setState(() => _fadeInColor = c),
                      showDropdownIcon: false,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Fade Out Row
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _fadeOut,
                      onChanged: (v) => setState(() => _fadeOut = v ?? false),
                      activeColor: Theme.of(context).colorScheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fade Out',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Fades to color at the end (1s)',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_fadeOut) ...[
                    const SizedBox(width: 8),
                    ColorPickerButton(
                      color: _fadeOutColor,
                      onColorChanged: (c) => setState(() => _fadeOutColor = c),
                      showDropdownIcon: false,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (_smoothTransition || _fadeIn || _fadeOut) ...[
          const SizedBox(height: 16),
          // Group: Encoding Settings (needed for transitions or fade effects)
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encoding Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required when using effects',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 16),
                CompactDropdown<String>(
                  value: _encodingPreset,
                  label: 'Encoding Speed:',
                  icon: Icons.speed,
                  items: const [
                    DropdownMenuItem(
                      value: 'ultrafast',
                      child: Text('Ultrafast'),
                    ),
                    DropdownMenuItem(
                      value: 'veryfast',
                      child: Text('Very Fast'),
                    ),
                    DropdownMenuItem(value: 'fast', child: Text('Fast')),
                  ],
                  onChanged: (v) =>
                      setState(() => _encodingPreset = v ?? 'veryfast'),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getPresetHint(_encodingPreset),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Divider(height: 24),
                CheckboxListTile(
                  title: Text(
                    'Hardware Acceleration',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Use GPU for faster encoding',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  value: _useHwAccel,
                  onChanged: (v) => setState(() => _useHwAccel = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Theme.of(context).colorScheme.primary,
                  dense: true,
                ),
                if (_useHwAccel) ...[
                  const SizedBox(height: 12),
                  CompactDropdown<String>(
                    value: _hwAccelEncoder,
                    label: 'Encoder:',
                    icon: Icons.memory,
                    items: const [
                      DropdownMenuItem(
                        value: 'libx264',
                        child: Text('Default (CPU)'),
                      ),
                      DropdownMenuItem(
                        value: 'h264_videotoolbox',
                        child: Text('macOS (Apple/Intel)'),
                      ),
                      DropdownMenuItem(
                        value: 'h264_nvenc',
                        child: Text('NVIDIA (Win/Linux)'),
                      ),
                      DropdownMenuItem(
                        value: 'h264_amf',
                        child: Text('AMD (Windows)'),
                      ),
                      DropdownMenuItem(
                        value: 'h264_qsv',
                        child: Text('Intel QuickSync'),
                      ),
                      DropdownMenuItem(
                        value: 'h264_vaapi',
                        child: Text('VAAPI (Linux)'),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _hwAccelEncoder = v ?? 'h264_videotoolbox',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _videoPaths.isNotEmpty ? _concatVideos : null,
            icon: const Icon(Icons.merge_type),
            label: Text(
              _videoPaths.length == 1 ? 'Process Video' : 'Merge Videos',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompressContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_compressVideoPath == null)
          DropZoneWidget(
            label: 'Drop Video Here (or Click)',
            icon: Icons.movie,
            onTap: _pickCompressVideo,
            onFilesDropped: (files) {
              final video = files.firstWhere(
                (f) => _videoExtensions.contains(
                  p.extension(f.path).replaceAll('.', '').toLowerCase(),
                ),
                orElse: () => files.first,
              );
              setState(() {
                _compressVideoPath = video.path;
              });
            },
          )
        else
          _buildMediaItem(
            context,
            _compressVideoPath!,
            Icons.movie,
            onRemove: () => setState(() => _compressVideoPath = null),
          ),
        const SizedBox(height: 24),
        // Group: Compression Settings
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compression Settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompactDropdown<int>(
                          value: _compressCrf,
                          label: 'Level:',
                          icon: Icons.compress,
                          items: const [
                            DropdownMenuItem(
                              value: 18,
                              child: Text('High Quality'),
                            ),
                            DropdownMenuItem(
                              value: 23,
                              child: Text('Balanced'),
                            ),
                            DropdownMenuItem(
                              value: 28,
                              child: Text('High Compression'),
                            ),
                            DropdownMenuItem(
                              value: 32,
                              child: Text('Tiny File'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _compressCrf = v ?? 23),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getCrfHint(_compressCrf),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompactDropdown<String>(
                          value: _compressPreset,
                          label: 'Speed:',
                          icon: Icons.speed,
                          items: const [
                            DropdownMenuItem(
                              value: 'ultrafast',
                              child: Text('Ultrafast'),
                            ),
                            DropdownMenuItem(
                              value: 'veryfast',
                              child: Text('Very Fast'),
                            ),
                            DropdownMenuItem(
                              value: 'fast',
                              child: Text('Fast'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'slow',
                              child: Text('Slow'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _compressPreset = v ?? 'veryfast'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getPresetHint(_compressPreset),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Group: Audio & Advanced
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
              CheckboxListTile(
                title: Text(
                  'Keep Audio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Copies original audio stream (No quality loss)',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: _compressKeepAudio,
                onChanged: (v) =>
                    setState(() => _compressKeepAudio = v ?? true),
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).colorScheme.primary,
                dense: true,
              ),
              const Divider(),
              CheckboxListTile(
                title: Text(
                  'Hardware Acceleration',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Use GPU for faster encoding',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: _useHwAccel,
                onChanged: (v) => setState(() => _useHwAccel = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).colorScheme.primary,
                dense: true,
              ),
              if (_useHwAccel) ...[
                const SizedBox(height: 12),
                CompactDropdown<String>(
                  value: _hwAccelEncoder,
                  label: 'Encoder:',
                  icon: Icons.memory,
                  items: const [
                    DropdownMenuItem(
                      value: 'libx264',
                      child: Text('Default (CPU)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_videotoolbox',
                      child: Text('macOS (Apple/Intel)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_nvenc',
                      child: Text('NVIDIA (Win/Linux)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_amf',
                      child: Text('AMD (Windows)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_qsv',
                      child: Text('Intel QuickSync'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_vaapi',
                      child: Text('VAAPI (Linux)'),
                    ),
                  ],
                  onChanged: (v) => setState(
                    () => _hwAccelEncoder = v ?? 'h264_videotoolbox',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _compressVideoPath != null ? _compressVideo : null,
            icon: const Icon(Icons.compress),
            label: const Text('Compress Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReencodeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_reencodeVideoPath == null)
          DropZoneWidget(
            label: 'Drop Video Here (or Click)',
            icon: Icons.movie,
            onTap: _pickReencodeVideo,
            onFilesDropped: (files) {
              final video = files.firstWhere(
                (f) => _videoExtensions.contains(
                  p.extension(f.path).replaceAll('.', '').toLowerCase(),
                ),
                orElse: () => files.first,
              );
              setState(() {
                _reencodeVideoPath = video.path;
              });
            },
          )
        else
          _buildMediaItem(
            context,
            _reencodeVideoPath!,
            Icons.movie,
            onRemove: () => setState(() => _reencodeVideoPath = null),
          ),
        const SizedBox(height: 24),
        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Use this to convert videos to specific resolution & frame rate. Perfect for preparing intro videos to match your main video format!',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Group: Output Format Settings
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Output Format',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyFormatFromVideo,
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: const Text('Copy from Video'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
              if (_reencodeReferenceVideoName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Format copied from: $_reencodeReferenceVideoName',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.green.shade800,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() => _reencodeReferenceVideoName = null);
                        },
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resolution',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        CompactDropdown<String>(
                          value: _reencodeResolution,
                          label: '',
                          icon: Icons.high_quality,
                          items: const [
                            DropdownMenuItem(
                              value: '480p',
                              child: Text('480p'),
                            ),
                            DropdownMenuItem(
                              value: '720p',
                              child: Text('720p'),
                            ),
                            DropdownMenuItem(
                              value: '1080p',
                              child: Text('1080p'),
                            ),
                            DropdownMenuItem(
                              value: '2K',
                              child: Text('2K (1440p)'),
                            ),
                            DropdownMenuItem(
                              value: '4K',
                              child: Text('4K (2160p)'),
                            ),
                            DropdownMenuItem(
                              value: '8K',
                              child: Text('8K (4320p)'),
                            ),
                          ],
                          onChanged: (v) => setState(
                            () => _reencodeResolution = v ?? '1080p',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aspect Ratio',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        CompactDropdown<String>(
                          value: _reencodeAspectRatio,
                          label: '',
                          icon: Icons.aspect_ratio,
                          items: const [
                            DropdownMenuItem(
                              value: 'original',
                              child: Text('Original (No Change)'),
                            ),
                            DropdownMenuItem(
                              value: '16:9',
                              child: Text('16:9 (Landscape)'),
                            ),
                            DropdownMenuItem(
                              value: '9:16',
                              child: Text('9:16 (Portrait)'),
                            ),
                            DropdownMenuItem(
                              value: '1:1',
                              child: Text('1:1 (Square)'),
                            ),
                            DropdownMenuItem(
                              value: '3:2',
                              child: Text('3:2'),
                            ),
                            DropdownMenuItem(
                              value: '2:3',
                              child: Text('2:3'),
                            ),
                          ],
                          onChanged: (v) => setState(
                            () => _reencodeAspectRatio = v ?? 'original',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frame Rate',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        CompactDropdown<int>(
                          value: _reencodeFps,
                          label: '',
                          icon: Icons.speed,
                          items: const [
                            DropdownMenuItem(value: 24, child: Text('24 fps')),
                            DropdownMenuItem(value: 25, child: Text('25 fps')),
                            DropdownMenuItem(value: 30, child: Text('30 fps')),
                            DropdownMenuItem(value: 60, child: Text('60 fps')),
                          ],
                          onChanged: (v) =>
                              setState(() => _reencodeFps = v ?? 30),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Show computed dimensions
              Builder(
                builder: (context) {
                  final dims = _getResolutionDimensions(
                    _reencodeResolution,
                    _reencodeAspectRatio,
                  );

                  String displayText;
                  if (dims == null) {
                    // Original aspect ratio - height only
                    final heightMap = {
                      '480p': 480,
                      '720p': 720,
                      '1080p': 1080,
                      '2K': 1440,
                      '4K': 2160,
                      '8K': 4320,
                    };
                    final height = heightMap[_reencodeResolution] ?? 1080;
                    displayText =
                        'Output: Height $height (keeps original aspect ratio)';
                  } else {
                    displayText = 'Output: ${dims.width} × ${dims.height}';
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayText,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              CompactDropdown<String>(
                value: _reencodePreset,
                label: 'Encoding Speed:',
                icon: Icons.speed,
                items: const [
                  DropdownMenuItem(
                    value: 'ultrafast',
                    child: Text('Ultrafast'),
                  ),
                  DropdownMenuItem(value: 'veryfast', child: Text('Very Fast')),
                  DropdownMenuItem(value: 'fast', child: Text('Fast')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'slow', child: Text('Slow')),
                ],
                onChanged: (v) =>
                    setState(() => _reencodePreset = v ?? 'veryfast'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Group: Audio & Hardware Acceleration
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
              CheckboxListTile(
                title: Text(
                  'Keep Audio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Re-encode audio to AAC format',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: _reencodeKeepAudio,
                onChanged: (v) =>
                    setState(() => _reencodeKeepAudio = v ?? true),
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).colorScheme.primary,
                dense: true,
              ),
              const Divider(),
              CheckboxListTile(
                title: Text(
                  'Hardware Acceleration',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Use GPU for faster encoding',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: _reencodeUseHwAccel,
                onChanged: (v) =>
                    setState(() => _reencodeUseHwAccel = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).colorScheme.primary,
                dense: true,
              ),
              if (_reencodeUseHwAccel) ...[
                const SizedBox(height: 12),
                CompactDropdown<String>(
                  value: _reencodeHwEncoder,
                  label: 'Encoder:',
                  icon: Icons.memory,
                  items: const [
                    DropdownMenuItem(
                      value: 'libx264',
                      child: Text('Default (CPU)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_videotoolbox',
                      child: Text('macOS (Apple/Intel)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_nvenc',
                      child: Text('NVIDIA (Win/Linux)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_amf',
                      child: Text('AMD (Windows)'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_qsv',
                      child: Text('Intel QuickSync'),
                    ),
                    DropdownMenuItem(
                      value: 'h264_vaapi',
                      child: Text('VAAPI (Linux)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _reencodeHwEncoder = v);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _reencodeVideoPath != null ? _reencodeVideo : null,
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('Process Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoInfoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_infoVideoPath == null)
          DropZoneWidget(
            label: 'Drop Video Here (or Click)',
            icon: Icons.movie,
            onTap: _pickInfoVideo,
            onFilesDropped: (files) {
              final video = files.firstWhere(
                (f) => _videoExtensions.contains(
                  p.extension(f.path).replaceAll('.', '').toLowerCase(),
                ),
                orElse: () => files.first,
              );
              setState(() {
                _infoVideoPath = video.path;
                _videoInfo = null;
              });
              _extractVideoInfo();
            },
          )
        else ...[
          _buildMediaItem(
            context,
            _infoVideoPath!,
            Icons.movie,
            onRemove: () => setState(() {
              _infoVideoPath = null;
              _videoInfo = null;
            }),
          ),
          const SizedBox(height: 24),
          if (_videoInfo != null) ...[
            // File Information
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'File Name',
                    (_videoInfo!['fileName'] as String?) ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'File Size',
                    _formatFileSize((_videoInfo!['fileSize'] as int?) ?? 0),
                  ),
                  _buildInfoRow(
                    'Duration',
                    _formatDuration(_videoInfo!['duration'] as Duration?),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Video Stream Information
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Video Stream',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Resolution',
                    '${_videoInfo!['width'] ?? 'N/A'} x ${_videoInfo!['height'] ?? 'N/A'}',
                  ),
                  _buildInfoRow(
                    'Frame Rate',
                    '${_videoInfo!['fps'] ?? 'N/A'} fps',
                  ),
                  _buildInfoRow(
                    'Codec',
                    (_videoInfo!['codec'] as String?) ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'Pixel Format',
                    (_videoInfo!['pixelFormat'] as String?) ?? 'Unknown',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Audio Stream Information
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.audiotrack,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Audio Stream',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Audio Present',
                    _videoInfo!['hasAudio'] == true ? 'Yes' : 'No',
                  ),
                ],
              ),
            ),
            // Metadata Tags Section
            if (_videoInfo!['metadataTags'] != null &&
                _videoInfo!['metadataTags'] is Map) ...[
              if ((_videoInfo!['metadataTags'] as Map)
                  .cast<String, String>()
                  .isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            color: Colors.purple[300],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Metadata Tags',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...(_videoInfo!['metadataTags'] as Map)
                          .cast<String, String>()
                          .entries
                          .map(
                            (entry) => _buildInfoRow(entry.key, entry.value),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'Unknown';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getPresetHint(String preset) {
    switch (preset) {
      case 'ultrafast':
        return 'Finishes instantly, but file might be larger. Use for quick tests.';
      case 'veryfast':
        return 'Recommended for most videos. Good balance.';
      case 'fast':
        return 'Slower than Very Fast, slightly better compression.';
      case 'medium':
      case 'slow':
        return 'Takes longer, but squeezes file smaller at same quality.';
      default:
        return '';
    }
  }

  String _getCrfHint(int crf) {
    if (crf <= 18) {
      return 'Best for archiving. Keeps almost all detail (Large File).';
    }
    if (crf <= 23) {
      return 'Best for sharing. Good quality, decent size (Default).';
    }
    if (crf <= 28) {
      return 'Best for Discord/WhatsApp. Shrinks file size a lot (Visible quality drop).';
    }
    return 'Best for very slow internet. Tiny file, pixelated.';
  }

  String _colorToHex(Color color) {
    // Convert Flutter Color to FFmpeg hex format (without alpha)
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  ({int width, int height})? _getResolutionDimensions(
    String resolution,
    String aspectRatio,
  ) {
    // If "original" is selected, return null (we'll compute at runtime)
    if (aspectRatio == 'original') {
      return null;
    }

    // Get base height from resolution preset
    final int baseHeight;
    switch (resolution) {
      case '480p':
        baseHeight = 480;
      case '720p':
        baseHeight = 720;
      case '1080p':
        baseHeight = 1080;
      case '2K':
        baseHeight = 1440;
      case '4K':
        baseHeight = 2160;
      case '8K':
        baseHeight = 4320;
      default:
        baseHeight = 1080;
    }

    // Calculate width based on aspect ratio and height
    final parts = aspectRatio.split(':');
    if (parts.length == 2) {
      final ratioW = int.tryParse(parts[0]) ?? 16;
      final ratioH = int.tryParse(parts[1]) ?? 9;
      final calculatedWidth = (baseHeight * ratioW / ratioH).round();
      // Ensure even dimensions (required by many codecs)
      final evenWidth = calculatedWidth.isEven
          ? calculatedWidth
          : calculatedWidth + 1;
      return (width: evenWidth, height: baseHeight);
    }

    // Fallback to 16:9 if parsing fails
    return (width: (baseHeight * 16 / 9).round(), height: baseHeight);
  }
}
