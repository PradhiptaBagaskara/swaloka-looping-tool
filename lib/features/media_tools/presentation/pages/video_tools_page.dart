import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/services/system_info_service.dart';
import 'package:swaloka_looping_tool/core/utils/timestamp_formatter.dart';
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
  final List<String> _reencodeVideoPaths = [];
  String _reencodeResolution = '1080p'; // 480p, 720p, 1080p, 2K, 4K, 8K
  String _reencodeAspectRatio =
      'original'; // original, 16:9, 9:16, 1:1, 3:2, 2:3
  int _reencodeFps = 30;
  String _reencodePreset = 'veryfast';
  String _reencodeQuality = 'auto'; // auto, high, balanced, smaller, tiny
  String _reencodeScalingQuality = 'high'; // fast, balanced, high
  bool _reencodeEnhanceQuality = false;
  bool _reencodeKeepAudio = true;
  bool _reencodeUseHwAccel = false;
  String _reencodeHwEncoder = 'libx264';
  String? _reencodeReferenceVideoName;

  // Video Info State
  String? _infoVideoPath;
  Map<String, dynamic>? _videoInfo;

  void _addUniquePaths(List<String> target, Iterable<String> paths) {
    final existing = target.toSet();
    for (final path in paths) {
      if (existing.add(path)) {
        target.add(path);
      }
    }
  }

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
    final project = ref.read(activeProjectProvider);
    final outputsDir = Directory(
      project?.effectiveOutputPath ??
          p.join(widget.initialDirectory, 'outputs'),
    );
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
        _addUniquePaths(_videoPaths, result.paths.whereType<String>());
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
      final timestamp = TimestampFormatter.format();
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
      final timestamp = TimestampFormatter.format();
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
      allowMultiple: true,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null) {
      setState(() {
        _addUniquePaths(_reencodeVideoPaths, result.paths.whereType<String>());
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
            content: Text('Menganalisis format video...'),
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
              'Format disalin: $resolution @ ${fps}fps',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } on Exception catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menganalisis video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reencodeVideos() async {
    if (_reencodeVideoPaths.isEmpty) return;

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
      final timestamp = TimestampFormatter.format();

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

      final project = ref.read(activeProjectProvider);
      final enableParallelProcessing =
          project?.enableParallelProcessing ?? true;
      final concurrencyLimit = SystemInfoService.getRecommendedConcurrency();
      final parallelism = enableParallelProcessing ? concurrencyLimit : 1;
      final safeParallelism = max(1, parallelism);

      final total = _reencodeVideoPaths.length;
      final maxWorkers = min(safeParallelism, total);
      final batchLog = LogEntry.info(
        'Re-encoding $total video(s) (parallel: $maxWorkers)...',
      );
      notifier.addLog(batchLog);

      var completed = 0;
      var nextIndex = 0;
      Object? firstError;

      String? lastOutputPath;

      int? crfOverride;
      switch (_reencodeQuality) {
        case 'high':
          crfOverride = 20;
        case 'balanced':
          crfOverride = 23;
        case 'smaller':
          crfOverride = 28;
        case 'tiny':
          crfOverride = 32;
        case 'auto':
        default:
          crfOverride = null;
      }

      Future<void> worker() async {
        while (true) {
          if (firstError != null) return;
          final current = nextIndex++;
          if (current >= total) return;

          final videoPath = _reencodeVideoPaths[current];
          final name = p.basenameWithoutExtension(videoPath);

          // Calculate dimensions based on aspect ratio
          int targetWidth;
          var preserveAspectRatio = false;

          if (_reencodeAspectRatio == 'original') {
            // Get original video dimensions to preserve aspect ratio
            final metadata = await FFmpegService.getVideoMetadata(videoPath);
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
            '${name}_${_reencodeResolution}_${aspectRatioLabel}_${_reencodeFps}fps_${timestamp}_$current.mp4',
          );

          try {
            await ref
                .read(mediaToolsServiceProvider)
                .reencodeVideo(
                  videoPath: videoPath,
                  outputPath: outputPath,
                  width: targetWidth,
                  height: targetHeight,
                  fps: _reencodeFps,
                  preset: _reencodePreset,
                  crf: crfOverride,
                  scalingQuality: _reencodeScalingQuality,
                  enhanceQuality: _reencodeEnhanceQuality,
                  keepAudio: _reencodeKeepAudio,
                  preserveAspectRatio: preserveAspectRatio,
                  hwEncoder: _reencodeUseHwAccel ? _reencodeHwEncoder : null,
                  onLog: batchLog.addSubLog,
                );
            lastOutputPath = outputPath;
          } on Exception catch (e) {
            firstError = e;
            return;
          } finally {
            if (firstError == null) {
              completed++;
              notifier.updateProgress(completed / total);
            }
          }
        }
      }

      await Future.wait(List.generate(maxWorkers, (_) => worker()));

      if (firstError != null) {
        throw firstError!; // handled below
      }

      notifier.setSuccess(lastOutputPath ?? outputsDir);
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
          content: Text('Gagal mengekstrak info video: $e'),
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
                  text: 'Gabung & Efek',
                  icon: Icon(Icons.video_library, size: 20),
                ),
                Tab(
                  text: 'Kompres Video',
                  icon: Icon(Icons.compress, size: 20),
                ),
                Tab(
                  text: 'Konversi Resolusi',
                  icon: Icon(Icons.settings_backup_restore, size: 20),
                ),
                Tab(
                  text: 'Info Video',
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
              : 'Seret File Video ke Sini (atau Klik)',
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
                _addUniquePaths(_videoPaths, videos);
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
                label: const Text('Hapus Semua'),
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
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _videoPaths.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final adjustedIndex = newIndex > oldIndex
                    ? newIndex - 1
                    : newIndex;
                final item = _videoPaths.removeAt(oldIndex);
                _videoPaths.insert(adjustedIndex, item);
              });
            },
            itemBuilder: (context, i) {
              return MediaItemCard(
                key: ValueKey(_videoPaths[i]),
                path: _videoPaths[i],
                icon: Icons.movie,
                onRemove: () {
                  setState(() {
                    _videoPaths.removeAt(i);
                  });
                },
                onPreview: () => _showPreview(
                  context,
                  _videoPaths[i],
                ),
                isVideo: true,
                index: i + 1,
              );
            },
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
                    'Mode video tunggal: Anda dapat menambahkan efek fade in/out. Transisi halus membutuhkan 2+ video.',
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
                  'Pertahankan Audio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Mempertahankan trek audio dalam video gabungan',
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
                  'Transisi Halus (Crossfade)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  _videoPaths.length <= 1
                      ? 'Membutuhkan 2 atau lebih video'
                      : 'Menambahkan crossfade 1 detik antara klip. Membutuhkan encoding ulang.',
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
                'Efek Fade',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bagus untuk membuat video yang ramah loop',
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
                          'Fade Masuk',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Fade dari warna di awal (1 detik)',
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
                          'Fade Keluar',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Fade ke warna di akhir (1 detik)',
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
                  'Pengaturan Encoding',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diperlukan saat menggunakan efek',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 16),
                CompactDropdown<String>(
                  value: _encodingPreset,
                  label: 'Kecepatan Encoding:',
                  icon: Icons.speed,
                  items: const [
                    DropdownMenuItem(
                      value: 'ultrafast',
                      child: Text('Ultra Cepat'),
                    ),
                    DropdownMenuItem(
                      value: 'veryfast',
                      child: Text('Sangat Cepat'),
                    ),
                    DropdownMenuItem(value: 'fast', child: Text('Cepat')),
                    DropdownMenuItem(value: 'slow', child: Text('Lambat')),
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
                    'Akselerasi Hardware',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Gunakan GPU untuk encoding lebih cepat',
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
              _videoPaths.length == 1 ? 'Proses Video' : 'Gabung Video',
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
            label: 'Seret Video ke Sini (atau Klik)',
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
          MediaItemCard(
            path: _compressVideoPath!,
            icon: Icons.movie,
            onRemove: () => setState(() => _compressVideoPath = null),
            onPreview: () => _showPreview(
              context,
              _compressVideoPath!,
            ),
            isVideo: true,
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
                'Pengaturan Kompresi',
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
                              child: Text('Kualitas Tinggi'),
                            ),
                            DropdownMenuItem(
                              value: 23,
                              child: Text('Seimbang'),
                            ),
                            DropdownMenuItem(
                              value: 28,
                              child: Text('Kompresi Tinggi'),
                            ),
                            DropdownMenuItem(
                              value: 32,
                              child: Text('File Kecil'),
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
                              child: Text('Ultra Cepat'),
                            ),
                            DropdownMenuItem(
                              value: 'veryfast',
                              child: Text('Sangat Cepat'),
                            ),
                            DropdownMenuItem(
                              value: 'fast',
                              child: Text('Cepat'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Sedang'),
                            ),
                            DropdownMenuItem(
                              value: 'slow',
                              child: Text('Lambat'),
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
                  'Pertahankan Audio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Menyalin stream audio asli (Tanpa kehilangan kualitas)',
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
                  'Akselerasi Hardware',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Gunakan GPU untuk encoding lebih cepat',
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
            label: const Text('Kompres Video'),
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
        DropZoneWidget(
          label: _reencodeVideoPaths.isNotEmpty
              ? '${_reencodeVideoPaths.length} ${_reencodeVideoPaths.length == 1 ? "file" : "files"} selected'
              : 'Seret File Video ke Sini (atau Klik)',
          icon: Icons.movie,
          onTap: _pickReencodeVideo,
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
                _addUniquePaths(_reencodeVideoPaths, videos);
              });
            }
          },
        ),
        if (_reencodeVideoPaths.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => setState(_reencodeVideoPaths.clear),
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('Hapus Semua'),
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
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reencodeVideoPaths.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final adjustedIndex = newIndex > oldIndex
                    ? newIndex - 1
                    : newIndex;
                final item = _reencodeVideoPaths.removeAt(oldIndex);
                _reencodeVideoPaths.insert(adjustedIndex, item);
              });
            },
            itemBuilder: (context, i) {
              return MediaItemCard(
                key: ValueKey(_reencodeVideoPaths[i]),
                path: _reencodeVideoPaths[i],
                icon: Icons.movie,
                onRemove: () {
                  setState(() {
                    _reencodeVideoPaths.removeAt(i);
                  });
                },
                onPreview: () => _showPreview(
                  context,
                  _reencodeVideoPaths[i],
                ),
                isVideo: true,
                index: i + 1,
              );
            },
          ),
        ],
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
                  'Konversi video ke resolusi & frame rate tertentu. Mendukung pemrosesan batch dan akan mengikuti pengaturan pemrosesan paralel proyek Anda.',
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
                    'Format Output',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyFormatFromVideo,
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: const Text('Salin dari Video'),
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
                          'Resolusi',
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
                          'Rasio Aspek',
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
                              child: Text('Asli (Tanpa Perubahan)'),
                            ),
                            DropdownMenuItem(
                              value: '16:9',
                              child: Text('16:9 (Lanskap)'),
                            ),
                            DropdownMenuItem(
                              value: '9:16',
                              child: Text('9:16 (Potret)'),
                            ),
                            DropdownMenuItem(
                              value: '1:1',
                              child: Text('1:1 (Persegi)'),
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
                        'Output: Tinggi $height (mempertahankan rasio aspek asli)';
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
                label: 'Kecepatan Encoding:',
                icon: Icons.speed,
                items: const [
                  DropdownMenuItem(
                    value: 'ultrafast',
                    child: Text('Ultra Cepat'),
                  ),
                  DropdownMenuItem(
                    value: 'veryfast',
                    child: Text('Sangat Cepat'),
                  ),
                  DropdownMenuItem(value: 'fast', child: Text('Cepat')),
                  DropdownMenuItem(value: 'medium', child: Text('Sedang')),
                  DropdownMenuItem(value: 'slow', child: Text('Lambat')),
                ],
                onChanged: (v) =>
                    setState(() => _reencodePreset = v ?? 'veryfast'),
              ),
              const SizedBox(height: 12),
              CompactDropdown<String>(
                value: _reencodeScalingQuality,
                label: 'Kualitas Scaling:',
                icon: Icons.photo_size_select_large,
                items: const [
                  DropdownMenuItem(
                    value: 'fast',
                    child: Text('Cepat (Bilinear)'),
                  ),
                  DropdownMenuItem(
                    value: 'balanced',
                    child: Text('Seimbang (Bicubic)'),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text('Tinggi (Lanczos)'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _reencodeScalingQuality = v ?? 'high'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Tingkatkan Kualitas',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const CompactTooltip(
                          message:
                              'Menerapkan denoise ringan + sharpening sedang.\n\n'
                              'Membuat upscale terlihat kurang lembut, tapi meningkatkan waktu pemrosesan.',
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: _reencodeEnhanceQuality,
                    onChanged: (v) =>
                        setState(() => _reencodeEnhanceQuality = v ?? false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CompactDropdown<String>(
                value: _reencodeQuality,
                label: 'Kualitas (CRF):',
                icon: Icons.high_quality,
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text('Kualitas Tinggi'),
                  ),
                  DropdownMenuItem(value: 'balanced', child: Text('Seimbang')),
                  DropdownMenuItem(
                    value: 'smaller',
                    child: Text('File Lebih Kecil'),
                  ),
                  DropdownMenuItem(value: 'tiny', child: Text('File Kecil')),
                ],
                onChanged: (v) =>
                    setState(() => _reencodeQuality = v ?? 'auto'),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CRF lebih rendah = kualitas lebih baik (file lebih besar). Menyesuaikan otomatis berdasarkan resolusi.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                  'Pertahankan Audio',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Encode ulang audio ke format AAC',
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
                  'Akselerasi Hardware',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Gunakan GPU untuk encoding lebih cepat',
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
            onPressed: _reencodeVideoPaths.isNotEmpty ? _reencodeVideos : null,
            icon: const Icon(Icons.settings_backup_restore),
            label: Text(
              _reencodeVideoPaths.length <= 1 ? 'Proses Video' : 'Proses Video',
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

  Widget _buildVideoInfoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_infoVideoPath == null)
          DropZoneWidget(
            label: 'Seret Video ke Sini (atau Klik)',
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
          MediaItemCard(
            path: _infoVideoPath!,
            icon: Icons.movie,
            onRemove: () => setState(() {
              _infoVideoPath = null;
              _videoInfo = null;
            }),
            onPreview: () => _showPreview(
              context,
              _infoVideoPath!,
            ),
            isVideo: true,
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
                    'Informasi File',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Nama File',
                    (_videoInfo!['fileName'] as String?) ?? 'Tidak Diketahui',
                  ),
                  _buildInfoRow(
                    'Ukuran File',
                    _formatFileSize((_videoInfo!['fileSize'] as int?) ?? 0),
                  ),
                  _buildInfoRow(
                    'Durasi',
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
                        'Stream Video',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Resolusi',
                    '${_videoInfo!['width'] ?? 'N/A'} x ${_videoInfo!['height'] ?? 'N/A'}',
                  ),
                  _buildInfoRow(
                    'Frame Rate',
                    '${_videoInfo!['fps'] ?? 'N/A'} fps',
                  ),
                  _buildInfoRow(
                    'Codec',
                    (_videoInfo!['codec'] as String?) ?? 'Tidak Diketahui',
                  ),
                  _buildInfoRow(
                    'Format Piksel',
                    (_videoInfo!['pixelFormat'] as String?) ??
                        'Tidak Diketahui',
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
                        'Stream Audio',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Audio Ada',
                    _videoInfo!['hasAudio'] == true ? 'Ya' : 'Tidak',
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
                            'Tag Metadata',
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
    if (duration == null) return 'Tidak Diketahui';
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
        return 'Selesai instan, tapi file mungkin lebih besar. Gunakan untuk tes cepat.';
      case 'veryfast':
        return 'Direkomendasikan untuk kebanyakan video. Keseimbangan yang baik.';
      case 'fast':
        return 'Lebih lambat dari Sangat Cepat, kompresi sedikit lebih baik.';
      case 'medium':
      case 'slow':
        return 'Memakan waktu lebih lama, tapi mengecilkan file dengan kualitas sama.';
      default:
        return '';
    }
  }

  String _getCrfHint(int crf) {
    if (crf <= 18) {
      return 'Terbaik untuk arsip. Menjaga hampir semua detail (File Besar).';
    }
    if (crf <= 23) {
      return 'Terbaik untuk berbagi. Kualitas baik, ukuran layak (Default).';
    }
    if (crf <= 28) {
      return 'Terbaik untuk Discord/WhatsApp. Mengecilkan ukuran file banyak (Penurunan kualitas terlihat).';
    }
    return 'Terbaik untuk internet sangat lambat. File kecil, piksel.';
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
