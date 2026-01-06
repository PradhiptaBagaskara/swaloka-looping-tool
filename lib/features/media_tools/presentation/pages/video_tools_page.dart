import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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

  @override
  void initState() {
    super.initState();
    // Set default HW encoder based on Platform
    if (Platform.isMacOS) {
      _hwAccelEncoder = 'h264_videotoolbox';
    } else if (Platform.isWindows) {
      _hwAccelEncoder = 'h264_nvenc';
    } else if (Platform.isLinux) {
      _hwAccelEncoder = 'h264_vaapi';
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
      final outputPath = p.join(outputsDir, 'merged_videos_$timestamp.mp4');

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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          ColoredBox(
            color: const Color(0xFF1A1A1A),
            child: TabBar(
              tabs: const [
                Tab(
                  text: 'Concatenate Videos',
                  icon: Icon(Icons.video_library, size: 20),
                ),
                Tab(
                  text: 'Compress Video',
                  icon: Icon(Icons.compress, size: 20),
                ),
              ],
              labelColor: Colors.deepPurple[200],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.deepPurple,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: const Color(0xFF333333),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTabContent(_buildConcatContent()),
                _buildTabContent(_buildCompressContent()),
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
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
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
              ? '${_videoPaths.length} files selected'
              : 'Drop Video Files Here (or Click)',
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
                  foregroundColor: Colors.grey,
                  textStyle: const TextStyle(fontSize: 12),
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
        // Group: Audio & Transitions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text(
                  'Keep Audio',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const Text(
                  'Preserves audio tracks in merged video',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                value: _keepAudio,
                onChanged: (v) => setState(() => _keepAudio = v ?? true),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.deepPurple,
                dense: true,
              ),
              const Divider(color: Colors.white10),
              CheckboxListTile(
                title: const Text(
                  'Smooth Transition (Crossfade)',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const Text(
                  'Adds 1s crossfade between clips. Requires re-encoding.',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                value: _smoothTransition,
                onChanged: (v) =>
                    setState(() => _smoothTransition = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.deepPurple,
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
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fade Effects',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Great for creating loop-friendly videos',
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
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
                      activeColor: Colors.deepPurple,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Fade In',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (_fadeIn) ...[
                    const SizedBox(width: 16),
                    ColorPickerButton(
                      color: _fadeInColor,
                      onColorChanged: (c) => setState(() => _fadeInColor = c),
                      size: 22,
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
                      activeColor: Colors.deepPurple,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Fade Out',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (_fadeOut) ...[
                    const SizedBox(width: 16),
                    ColorPickerButton(
                      color: _fadeOutColor,
                      onColorChanged: (c) => setState(() => _fadeOutColor = c),
                      size: 22,
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
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Encoding Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required when using effects',
                  style: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 24),
                CheckboxListTile(
                  title: const Text(
                    'Hardware Acceleration',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Use GPU for faster encoding',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  value: _useHwAccel,
                  onChanged: (v) => setState(() => _useHwAccel = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.deepPurple,
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
        ElevatedButton.icon(
          onPressed: _videoPaths.length > 1 ? _concatVideos : null,
          icon: const Icon(Icons.merge_type),
          label: const Text('Merge Videos'),
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
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compression Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
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
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
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
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text(
                  'Keep Audio',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const Text(
                  'Copies original audio stream (No quality loss)',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                value: _compressKeepAudio,
                onChanged: (v) =>
                    setState(() => _compressKeepAudio = v ?? true),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.deepPurple,
                dense: true,
              ),
              const Divider(color: Colors.white10),
              CheckboxListTile(
                title: const Text(
                  'Hardware Acceleration',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const Text(
                  'Use GPU for faster encoding',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                value: _useHwAccel,
                onChanged: (v) => setState(() => _useHwAccel = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.deepPurple,
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
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
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
}
