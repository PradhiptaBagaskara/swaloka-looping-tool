import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/utils/timestamp_formatter.dart';
import 'package:swaloka_looping_tool/features/media_tools/domain/media_tools_service.dart';
import 'package:swaloka_looping_tool/features/media_tools/presentation/providers/media_tools_providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/widgets.dart';

const _audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];

class _AudioOverlay {
  const _AudioOverlay({
    required this.path,
    required this.volume,
    this.isPlaying,
  });

  final String path;
  final double volume; // 0.0 to 1.0
  final bool? isPlaying;

  bool get playing => isPlaying ?? false;

  _AudioOverlay copyWith({String? path, double? volume, bool? isPlaying}) {
    return _AudioOverlay(
      path: path ?? this.path,
      volume: volume ?? this.volume,
      isPlaying: isPlaying,
    );
  }
}

class AudioToolsPage extends ConsumerStatefulWidget {
  const AudioToolsPage({required this.initialDirectory, super.key});
  final String initialDirectory;

  @override
  ConsumerState<AudioToolsPage> createState() => _AudioToolsPageState();
}

class _AudioToolsPageState extends ConsumerState<AudioToolsPage> {
  // Base Audio State
  final List<String> _baseAudios = [];
  int? _currentBaseAudioIndex; // Which base audio is currently playing
  bool _isBaseAudioPlaying = false;

  // Audio Overlay State
  final List<_AudioOverlay> _audioOverlays = [];

  Future<String> _ensureOutputsDir() async {
    final outputsDir = Directory(p.join(widget.initialDirectory, 'outputs'));
    if (!await outputsDir.exists()) {
      await outputsDir.create(recursive: true);
    }
    return outputsDir.path;
  }

  Future<void> _pickBaseAudios() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      initialDirectory: widget.initialDirectory,
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
      type: FileType.audio,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioOverlays.add(
          _AudioOverlay(
            path: result.files.single.path!,
            volume: 1,
          ),
        );
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
          // Move to next audio
          _currentBaseAudioIndex = _currentBaseAudioIndex! + 1;
        } else {
          // End of sequence
          _isBaseAudioPlaying = false;
          _currentBaseAudioIndex = null;
        }
      });
    }
  }

  void _toggleOverlayPlayback(int index) {
    setState(() {
      _audioOverlays[index] = _audioOverlays[index].copyWith(
        isPlaying: !_audioOverlays[index].playing,
      );
    });
  }

  Future<void> _processAudioWithOverlays() async {
    if (_baseAudios.isEmpty && _audioOverlays.isEmpty) return;

    await _runOperation((logCallback) async {
      final outputDir = await _ensureOutputsDir();
      final timestamp = TimestampFormatter.format();
      final outputPath = p.join(outputDir, 'audio_output_$timestamp.m4a');

      // If only overlays, no base audio
      if (_baseAudios.isEmpty) {
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
              baseAudios: _baseAudios,
              overlays: _audioOverlays
                  .map(
                    (e) => AudioOverlayConfig(path: e.path, volume: e.volume),
                  )
                  .toList(),
              outputPath: outputPath,
              onLog: logCallback,
            );
      }

      // Update success state with output path for preview
      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
    });
  }

  Future<void> _runOperation(
    Future<void> Function(void Function(LogEntry)) operation,
  ) async {
    final notifier = ref.read(processingStateProvider.notifier);
    notifier.startProcessing();

    // Show dialog
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MergeProgressDialog(),
      ),
    );

    try {
      await operation(notifier.addLog);
      // Success state is set within the specific operation functions to include output path
    } on Exception catch (e) {
      notifier.setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBaseAudioSection(),
                const SizedBox(height: 24),
                _buildAudioOverlaySection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaseAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base Audio (Loop in Sequence)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        DropZoneWidget(
          label: 'Drop Base Audio Files Here (or Click)',
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
          ...List.generate(_baseAudios.length, (i) {
            final audio = _baseAudios[i];
            final isCurrent =
                _currentBaseAudioIndex == i && _isBaseAudioPlaying;
            final isPast =
                _currentBaseAudioIndex != null && i < _currentBaseAudioIndex!;

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
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
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
                      if (i == 0)
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
                          onPressed: () => _toggleBaseAudioPlayback(0),
                          tooltip: 'Play Sequence',
                        )
                      else
                        const SizedBox(width: 48),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _baseAudios.removeAt(i);
                            if (_currentBaseAudioIndex != null &&
                                _currentBaseAudioIndex! >= _baseAudios.length) {
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
          }),
        ],
      ],
    );
  }

  Widget _buildAudioOverlaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio Overlay',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        DropZoneWidget(
          label: 'Drop Overlay Audio Files Here (or Click)',
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
                  _audioOverlays.add(
                    _AudioOverlay(
                      path: audio,
                      volume: 1,
                    ),
                  );
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
              TextButton.icon(
                onPressed: () => setState(_audioOverlays.clear),
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
          ...List.generate(_audioOverlays.length, (i) {
            final overlay = _audioOverlays[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: overlay.playing
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: overlay.playing
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                  width: overlay.playing ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 20,
                        color: overlay.playing
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.basename(overlay.path),
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          overlay.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_outline,
                          color: overlay.playing
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer
                              : null,
                        ),
                        onPressed: () => _toggleOverlayPlayback(i),
                        tooltip: overlay.playing ? 'Pause' : 'Play',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _audioOverlays.removeAt(i);
                          });
                        },
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Volume slider (always visible)
                  Row(
                    children: [
                      Icon(
                        Icons.volume_down,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Slider(
                          value: overlay.volume,
                          divisions: 100,
                          label: '${(overlay.volume * 100).toInt()}%',
                          onChanged: (value) {
                            setState(() {
                              _audioOverlays[i] = overlay.copyWith(
                                volume: value,
                              );
                            });
                          },
                        ),
                      ),
                      Icon(
                        Icons.volume_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(overlay.volume * 100).toInt()}%',
                          style: Theme.of(context).textTheme.labelSmall,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Inline player (shows when playing)
                  if (overlay.playing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: KeepAlive(
                        keepAlive: true,
                        child: MediaPreviewPlayer(
                          key: ValueKey('overlay_${overlay.path}'),
                          path: overlay.path,
                          isVideo: false,
                          volume: overlay.volume,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: (_baseAudios.isNotEmpty || _audioOverlays.isNotEmpty)
              ? _processAudioWithOverlays
              : null,
          icon: const Icon(Icons.layers),
          label: const Text('Apply Overlays'),
        ),
      ],
    );
  }
}
