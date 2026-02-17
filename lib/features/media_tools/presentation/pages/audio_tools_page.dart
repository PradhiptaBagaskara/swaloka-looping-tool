import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/features/media_tools/presentation/providers/media_tools_providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/widgets.dart';

const _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'];
const _audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'];

class AudioToolsPage extends ConsumerStatefulWidget {
  const AudioToolsPage({required this.initialDirectory, super.key});
  final String initialDirectory;

  @override
  ConsumerState<AudioToolsPage> createState() => _AudioToolsPageState();
}

class _AudioToolsPageState extends ConsumerState<AudioToolsPage> {
  // Extract Audio State
  String? _extractVideoPath;
  String _extractFormat = 'aac';

  // Concat Audio State
  final List<String> _concatAudioPaths = [];
  String _concatFormat = 'aac';

  // Convert Audio State
  String? _convertAudioPath;
  String _convertFormat = 'aac';

  // Common Formats
  final _audioFormats = ['aac', 'mp3', 'wav', 'm4a', 'ogg', 'flac'];

  Future<String> _ensureOutputsDir() async {
    final outputsDir = Directory(p.join(widget.initialDirectory, 'outputs'));
    if (!await outputsDir.exists()) {
      await outputsDir.create(recursive: true);
    }
    return outputsDir.path;
  }

  Future<void> _pickExtractVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _extractVideoPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickConcatAudios() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null) {
      setState(() {
        _concatAudioPaths.addAll(result.paths.whereType<String>().toList());
      });
    }
  }

  Future<void> _pickConvertAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      initialDirectory: widget.initialDirectory,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _convertAudioPath = result.files.single.path;
      });
    }
  }

  Future<void> _extractAudio() async {
    if (_extractVideoPath == null) return;
    await _runOperation((logCallback) async {
      final outputDir = await _ensureOutputsDir();
      final name = p.basenameWithoutExtension(_extractVideoPath!);
      final outputPath = p.join(outputDir, '${name}_extracted.$_extractFormat');

      await ref
          .read(mediaToolsServiceProvider)
          .extractAudio(
            videoPath: _extractVideoPath!,
            outputPath: outputPath,
            onLog: logCallback,
          );

      // Update success state with output path for preview
      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
    });
  }

  Future<void> _concatAudio() async {
    if (_concatAudioPaths.isEmpty) return;
    await _runOperation((logCallback) async {
      final outputDir = await _ensureOutputsDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(
        outputDir,
        'concatenated_$timestamp.$_concatFormat',
      );

      await ref
          .read(mediaToolsServiceProvider)
          .concatAudio(
            audioPaths: _concatAudioPaths,
            outputPath: outputPath,
            onLog: logCallback,
          );

      // Update success state with output path for preview
      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
    });
  }

  Future<void> _convertAudio() async {
    if (_convertAudioPath == null) return;
    await _runOperation((logCallback) async {
      final outputDir = await _ensureOutputsDir();
      final name = p.basenameWithoutExtension(_convertAudioPath!);
      final outputPath = p.join(outputDir, '${name}_converted.$_convertFormat');

      await ref
          .read(mediaToolsServiceProvider)
          .convertAudio(
            inputPath: _convertAudioPath!,
            outputPath: outputPath,
            onLog: logCallback,
          );

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

  void _showPreview(BuildContext context, String path, {bool isVideo = false}) {
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
      length: 3,
      child: Column(
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: TabBar(
              tabs: const [
                Tab(
                  text: 'Extract Audio',
                  icon: Icon(Icons.audio_file, size: 20),
                ),
                Tab(
                  text: 'Merge Audio',
                  icon: Icon(Icons.merge_type, size: 20),
                ),
                Tab(
                  text: 'Convert Format',
                  icon: Icon(Icons.transform, size: 20),
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
                _buildTabContent(_buildExtractContent()),
                _buildTabContent(_buildMergeContent()),
                _buildTabContent(_buildConvertContent()),
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

  Widget _buildExtractContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_extractVideoPath == null)
          DropZoneWidget(
            label: 'Drop Video Here (or Click)',
            icon: Icons.movie,
            onTap: _pickExtractVideo,
            onFilesDropped: (files) {
              final video = files.firstWhere(
                (f) => _videoExtensions.contains(
                  p.extension(f.path).replaceAll('.', '').toLowerCase(),
                ),
                orElse: () => files.first,
              );
              setState(() {
                _extractVideoPath = video.path;
              });
            },
          )
        else
          MediaItemCard(
            path: _extractVideoPath!,
            icon: Icons.movie,
            isVideo: true,
            onRemove: () => setState(() => _extractVideoPath = null),
            onPreview: () => _showPreview(
              context,
              _extractVideoPath!,
              isVideo: true,
            ),
          ),
        const SizedBox(height: 16),
        _buildFormatDropdown(
          value: _extractFormat,
          onChanged: (v) => setState(() => _extractFormat = v!),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _extractVideoPath != null ? _extractAudio : null,
          icon: const Icon(Icons.download),
          label: const Text('Extract Audio'),
        ),
      ],
    );
  }

  Widget _buildMergeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropZoneWidget(
          label: 'Drop Audio Files Here (or Click)',
          icon: Icons.audiotrack,
          onTap: _pickConcatAudios,
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
                _concatAudioPaths.addAll(audios);
              });
            }
          },
        ),
        if (_concatAudioPaths.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => setState(_concatAudioPaths.clear),
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
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _concatAudioPaths.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = _concatAudioPaths.removeAt(oldIndex);
                _concatAudioPaths.insert(newIndex, item);
              });
            },
            itemBuilder: (context, i) {
              return MediaItemCard(
                key: ValueKey(_concatAudioPaths[i]),
                path: _concatAudioPaths[i],
                icon: Icons.music_note,
                onRemove: () {
                  setState(() {
                    _concatAudioPaths.removeAt(i);
                  });
                },
                onPreview: () => _showPreview(
                  context,
                  _concatAudioPaths[i],
                ),
                index: i + 1,
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        _buildFormatDropdown(
          value: _concatFormat,
          onChanged: (v) => setState(() => _concatFormat = v!),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _concatAudioPaths.isNotEmpty ? _concatAudio : null,
          icon: const Icon(Icons.merge),
          label: const Text('Merge Audios'),
        ),
      ],
    );
  }

  Widget _buildConvertContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_convertAudioPath == null)
          DropZoneWidget(
            label: 'Drop Audio File Here (or Click)',
            icon: Icons.music_note,
            onTap: _pickConvertAudio,
            onFilesDropped: (files) {
              final audio = files.firstWhere(
                (f) => _audioExtensions.contains(
                  p.extension(f.path).replaceAll('.', '').toLowerCase(),
                ),
                orElse: () => files.first,
              );
              setState(() {
                _convertAudioPath = audio.path;
              });
            },
          )
        else
          MediaItemCard(
            path: _convertAudioPath!,
            icon: Icons.music_note,
            onRemove: () => setState(() => _convertAudioPath = null),
            onPreview: () => _showPreview(
              context,
              _convertAudioPath!,
            ),
          ),
        const SizedBox(height: 16),
        _buildFormatDropdown(
          value: _convertFormat,
          onChanged: (v) => setState(() => _convertFormat = v!),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _convertAudioPath != null ? _convertAudio : null,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Convert'),
        ),
      ],
    );
  }

  Widget _buildFormatDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return CompactDropdown<String>(
      value: value,
      label: 'Output Format:',
      items: _audioFormats
          .map(
            (f) => DropdownMenuItem(
              value: f,
              child: Text(f.toUpperCase()),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
