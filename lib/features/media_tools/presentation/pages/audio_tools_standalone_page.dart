import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/features/media_tools/domain/media_tools_service.dart';
import 'package:swaloka_looping_tool/features/media_tools/presentation/providers/media_tools_providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/widgets.dart';
import 'package:video_player/video_player.dart';

const _audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];

class _AudioOverlay {
  const _AudioOverlay({
    required this.path,
    required this.volume,
  });

  final String path;
  final double volume; // 0.0 to 1.0

  _AudioOverlay copyWith({String? path, double? volume}) {
    return _AudioOverlay(
      path: path ?? this.path,
      volume: volume ?? this.volume,
    );
  }
}

/// Widget for a single audio overlay item with independent player controller
/// Each overlay manages its own state - no shared state, no race conditions
class _AudioOverlayItem extends StatefulWidget {
  const _AudioOverlayItem({
    required this.path,
    required this.initialVolume,
    required this.onVolumeChanged,
    required this.onRemove,
    this.onPlayingStateChanged,
    super.key,
  });

  final String path;
  final double initialVolume;
  final void Function(double volume) onVolumeChanged;
  final VoidCallback onRemove;
  final VoidCallback? onPlayingStateChanged;

  @override
  State<_AudioOverlayItem> createState() => _AudioOverlayItemState();
}

class _AudioOverlayItemState extends State<_AudioOverlayItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume;
    _initPlayer();
  }

  void _initPlayer() {
    _controller = VideoPlayerController.file(File(widget.path));

    _controller!.addListener(_onControllerUpdate);

    _controller!
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _initialized = true;
            });
            _controller!.setVolume(_volume);
            _controller!.setLooping(true);
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() {
              _initialized = true;
            });
          }
        });
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    // Just rebuild to update UI (play/pause button, progress bar)
    setState(() {});
    // Notify parent to update Play All/Stop All button
    widget.onPlayingStateChanged?.call();
  }

  @override
  void didUpdateWidget(_AudioOverlayItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update volume if changed
    if (oldWidget.initialVolume != widget.initialVolume) {
      _volume = widget.initialVolume;
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        controller.setVolume(_volume);
      }
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
    // Notify parent of state change
    widget.onPlayingStateChanged?.call();
  }

  /// Public method to play this overlay
  void play() {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying) {
      controller.play();
      setState(() {});
      // Notify parent of state change
      widget.onPlayingStateChanged?.call();
    }
  }

  /// Public method to pause this overlay
  void pause() {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying) {
      controller.pause();
      setState(() {});
      // Notify parent of state change
      widget.onPlayingStateChanged?.call();
    }
  }

  /// Public method to check if this overlay is playing
  bool get isPlaying {
    final controller = _controller;
    return controller != null && controller.value.isPlaying;
  }

  void _disposePlayer() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    _controller = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.path);
    final controller = _controller;
    final isPlaying =
        _initialized && controller != null && controller.value.isPlaying;
    final position = _initialized && controller != null
        ? controller.value.position
        : Duration.zero;
    final duration = _initialized && controller != null
        ? controller.value.duration
        : Duration.zero;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isPlaying
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPlaying
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          width: isPlaying ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note,
                size: 16,
                color: isPlaying
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Play/Pause button
              InkWell(
                onTap: _togglePlayPause,
                child: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_outline,
                  size: 28,
                  color: isPlaying
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : null,
                ),
              ),
              // Remove button
              InkWell(
                onTap: widget.onRemove,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Volume slider (always visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.volume_down,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: _volume,
                      divisions: 100,
                      label: '${(_volume * 100).toInt()}%',
                      onChanged: (value) {
                        setState(() {
                          _volume = value;
                        });
                        final controller = _controller;
                        if (controller != null &&
                            controller.value.isInitialized) {
                          controller.setVolume(_volume);
                        }
                        widget.onVolumeChanged(value);
                      },
                    ),
                  ),
                ),
                Icon(
                  Icons.volume_up,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${(_volume * 100).toInt()}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Progress bar and time (shows when playing)
          if (isPlaying)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 4,
                        ),
                        trackHeight: 2,
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble(),
                        max: duration.inMilliseconds.toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        activeColor: Theme.of(context).colorScheme.secondary,
                        inactiveColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        onChanged: (v) {
                          _controller?.seekTo(
                            Duration(milliseconds: v.toInt()),
                          );
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(position),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    ' / ${_formatDuration(duration)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Standalone audio tools page with split layout for base audios and overlays
class AudioToolsStandalonePage extends ConsumerStatefulWidget {
  const AudioToolsStandalonePage({required this.projectRootPath, super.key});
  final String projectRootPath;

  @override
  ConsumerState<AudioToolsStandalonePage> createState() =>
      _AudioToolsStandalonePageState();
}

class _AudioToolsStandalonePageState
    extends ConsumerState<AudioToolsStandalonePage> {
  // Base Audio State
  final List<String> _baseAudios = [];
  int? _currentBaseAudioIndex;
  bool _isBaseAudioPlaying = false;
  int _baseAudioLoopCount = 1;
  late final TextEditingController _loopCountController;

  // Audio Overlay State
  final List<_AudioOverlay> _audioOverlays = [];
  final List<GlobalKey<_AudioOverlayItemState>> _overlayKeys = [];

  // Output format state
  String _outputFormat = 'm4a';

  // Available output formats
  static const List<String> _outputFormats = ['m4a', 'mp3', 'wav', 'flac'];

  @override
  void initState() {
    super.initState();
    _loopCountController = TextEditingController(
      text: _baseAudioLoopCount.toString(),
    );
  }

  @override
  void dispose() {
    _loopCountController.dispose();
    super.dispose();
  }

  /// Callback when any overlay's playing state changes
  void _onOverlayPlayingStateChanged() {
    // Rebuild to update Play All/Stop All button state
    setState(() {});
  }

  /// Play all overlay audio simultaneously
  void _playAllOverlays() {
    for (final key in _overlayKeys) {
      key.currentState?.play();
    }
  }

  /// Pause all overlay audio
  void _pauseAllOverlays() {
    for (final key in _overlayKeys) {
      key.currentState?.pause();
    }
  }

  /// Check if any overlay is currently playing
  bool get _anyOverlayPlaying {
    for (final key in _overlayKeys) {
      if (key.currentState?.isPlaying ?? false) {
        return true;
      }
    }
    return false;
  }

  Future<String> _ensureOutputsDir() async {
    final outputsDir = Directory(p.join(widget.projectRootPath, 'outputs'));
    if (!await outputsDir.exists()) {
      await outputsDir.create(recursive: true);
    }
    return outputsDir.path;
  }

  Future<void> _pickBaseAudios() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      initialDirectory: widget.projectRootPath,
    );
    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            _baseAudios.add(file.path!);
          }
        }
      });
    }
  }

  Future<void> _pickAudioOverlay() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
      allowMultiple: true,
      initialDirectory: widget.projectRootPath,
    );
    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            final key = GlobalKey<_AudioOverlayItemState>();
            _audioOverlays.add(
              _AudioOverlay(
                path: file.path!,
                volume: 1,
              ),
            );
            _overlayKeys.add(key);
          }
        }
      });
    }
  }

  void _toggleBaseAudioPlayback(int startIndex) {
    setState(() {
      if (_currentBaseAudioIndex == startIndex && _isBaseAudioPlaying) {
        _isBaseAudioPlaying = false;
        _currentBaseAudioIndex = null;
      } else {
        _currentBaseAudioIndex = startIndex;
        _isBaseAudioPlaying = true;
      }
    });
  }

  void _onBaseAudioCompleted() {
    if (_currentBaseAudioIndex != null && _isBaseAudioPlaying) {
      setState(() {
        if (_currentBaseAudioIndex! < _baseAudios.length - 1) {
          _currentBaseAudioIndex = _currentBaseAudioIndex! + 1;
        } else {
          _isBaseAudioPlaying = false;
          _currentBaseAudioIndex = null;
        }
      });
    }
  }

  Future<void> _processAudioWithOverlays() async {
    if (_baseAudios.isEmpty && _audioOverlays.isEmpty) return;

    await _runOperation((logCallback) async {
      final outputDir = await _ensureOutputsDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(
        outputDir,
        'audio_output_$timestamp.$_outputFormat',
      );

      // Expand base audios based on loop count
      var expandedBaseAudios = <String>[];
      if (_baseAudios.isNotEmpty) {
        if (_baseAudioLoopCount == 1) {
          expandedBaseAudios = List.from(_baseAudios);
        } else {
          // Repeat and shuffle base audios for each loop iteration
          for (var i = 0; i < _baseAudioLoopCount; i++) {
            // Shuffle the base audios
            final shuffled = List<String>.from(_baseAudios)..shuffle();
            expandedBaseAudios.addAll(shuffled);
          }
        }
      }

      // If only overlays, no base audio
      if (expandedBaseAudios.isEmpty) {
        await ref
            .read(mediaToolsServiceProvider)
            .applyAudioOverlays(
              overlays: _audioOverlays
                  .map(
                    (e) => AudioOverlayConfig(path: e.path, volume: e.volume),
                  )
                  .toList(),
              outputPath: outputPath,
              onLog: logCallback,
            );
      } else {
        // Base audios + overlays
        await ref
            .read(mediaToolsServiceProvider)
            .applyAudioOverlaysToBaseAudios(
              baseAudios: expandedBaseAudios,
              overlays: _audioOverlays
                  .map(
                    (e) => AudioOverlayConfig(path: e.path, volume: e.volume),
                  )
                  .toList(),
              outputPath: outputPath,
              onLog: logCallback,
            );
      }

      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
    });
  }

  Future<void> _runOperation(
    Future<void> Function(void Function(LogEntry)) operation,
  ) async {
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
      await operation(notifier.addLog);
    } on Exception catch (e) {
      notifier.setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button, title, and controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back to Video Editor',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Audio Tools',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Output format dropdown (smaller)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.audio_file,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        DropdownButton<String>(
                          value: _outputFormat,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          underline: const SizedBox.shrink(),
                          items: _outputFormats.map((format) {
                            return DropdownMenuItem<String>(
                              value: format,
                              child: Text(format.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _outputFormat = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Process Audio button (bigger)
                  ElevatedButton.icon(
                    onPressed:
                        (_baseAudios.isNotEmpty || _audioOverlays.isNotEmpty)
                        ? _processAudioWithOverlays
                        : null,
                    icon: const Icon(Icons.merge, size: 20),
                    label: const Text('Process Audio'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Split view: Base Audios (Left) and Overlay Audios (Right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Base Audios
                  Expanded(
                    child: _buildBaseAudioSection(),
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  // RIGHT: Overlay Audios
                  Expanded(
                    child: _buildAudioOverlaySection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseAudioSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Base Audio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loop in Sequence',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Loop count input
          Row(
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Loop Count:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _loopCountController,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    if (intValue != null && intValue >= 1) {
                      setState(() {
                        _baseAudioLoopCount = intValue;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropZoneWidget(
            label: 'Drop Base Audio Files Here',
            icon: Icons.music_note,
            onTap: _pickBaseAudios,
            onFilesDropped: (files) {
              final audios = files
                  .where(
                    (f) => _audioExtensions.contains(
                      p.extension(f.path).replaceAll('.', '').toLowerCase(),
                    ),
                  )
                  .map((f) => f.path)
                  .toList();
              if (audios.isNotEmpty) {
                setState(() {
                  _baseAudios.addAll(audios);
                });
              }
            },
          ),
          if (_baseAudios.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _baseAudios.clear();
                    _currentBaseAudioIndex = null;
                    _isBaseAudioPlaying = false;
                  }),
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
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _baseAudios.length,
                itemBuilder: (context, i) {
                  final audio = _baseAudios[i];
                  final isCurrent =
                      _currentBaseAudioIndex == i && _isBaseAudioPlaying;
                  final isPast =
                      _currentBaseAudioIndex != null &&
                      i < _currentBaseAudioIndex!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.5),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              isPast
                                  ? Icons.check_circle
                                  : isCurrent
                                  ? Icons.play_circle_filled
                                  : Icons.audiotrack,
                              size: 20,
                              color: isPast
                                  ? Colors.green
                                  : isCurrent
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.basename(audio),
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Play/Pause button - start sequence from this position
                            IconButton(
                              icon: Icon(
                                isCurrent && _isBaseAudioPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: isCurrent
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : null,
                              ),
                              onPressed: () => _toggleBaseAudioPlayback(i),
                              tooltip: 'Play from here',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _baseAudios.removeAt(i);
                                  if (_currentBaseAudioIndex != null &&
                                      _currentBaseAudioIndex! >=
                                          _baseAudios.length) {
                                    _currentBaseAudioIndex = null;
                                    _isBaseAudioPlaying = false;
                                  }
                                });
                              },
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                        if (isCurrent && _currentBaseAudioIndex == i) ...[
                          const SizedBox(height: 8),
                          MediaPreviewPlayer(
                            key: ValueKey('base_$i'),
                            path: audio,
                            isVideo: false,
                            onPlaybackComplete: _onBaseAudioCompleted,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioOverlaySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Overlay',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play simultaneously, adjust volume per track',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          DropZoneWidget(
            label: 'Drop Overlay Audio Files',
            icon: Icons.layers,
            onTap: _pickAudioOverlay,
            onFilesDropped: (files) {
              final audios = files
                  .where(
                    (f) => _audioExtensions.contains(
                      p.extension(f.path).replaceAll('.', '').toLowerCase(),
                    ),
                  )
                  .map((f) => f.path)
                  .toList();
              if (audios.isNotEmpty) {
                setState(() {
                  for (final audio in audios) {
                    final key = GlobalKey<_AudioOverlayItemState>();
                    _audioOverlays.add(
                      _AudioOverlay(
                        path: audio,
                        volume: 1,
                      ),
                    );
                    _overlayKeys.add(key);
                  }
                });
              }
            },
          ),
          if (_audioOverlays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Play All / Stop All button
                TextButton.icon(
                  onPressed: () {
                    if (_anyOverlayPlaying) {
                      _pauseAllOverlays();
                    } else {
                      _playAllOverlays();
                    }
                  },
                  icon: Icon(
                    _anyOverlayPlaying ? Icons.stop : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(_anyOverlayPlaying ? 'Stop All' : 'Play All'),
                  style: TextButton.styleFrom(
                    foregroundColor: _anyOverlayPlaying
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    textStyle: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _audioOverlays.clear();
                    _overlayKeys.clear();
                  }),
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
            Expanded(
              child: ListView.builder(
                itemCount: _audioOverlays.length,
                itemBuilder: (context, i) {
                  final overlay = _audioOverlays[i];
                  final key = i < _overlayKeys.length ? _overlayKeys[i] : null;
                  return _AudioOverlayItem(
                    key: key,
                    path: overlay.path,
                    initialVolume: overlay.volume,
                    onVolumeChanged: (volume) {
                      // Update parent state without rebuild
                      _audioOverlays[i] = overlay.copyWith(volume: volume);
                    },
                    onRemove: () {
                      setState(() {
                        _audioOverlays.removeAt(i);
                        if (i < _overlayKeys.length) {
                          _overlayKeys.removeAt(i);
                        }
                      });
                    },
                    onPlayingStateChanged: _onOverlayPlayingStateChanged,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
