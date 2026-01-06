import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/utils/log_formatter.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/log_entry_widget.dart';
import 'package:swaloka_looping_tool/widgets/media_preview_player.dart';
import 'package:url_launcher/url_launcher.dart';

class MergeProgressDialog extends ConsumerStatefulWidget {
  const MergeProgressDialog({super.key});

  @override
  ConsumerState<MergeProgressDialog> createState() =>
      _MergeProgressDialogState();
}

class _MergeProgressDialogState extends ConsumerState<MergeProgressDialog> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _textScrollController = ScrollController();
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final state = ref.read(processingStateProvider);
      final startTime = state.startTime;
      if (startTime != null && state.isProcessing) {
        setState(() {
          _elapsed = DateTime.now().difference(startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textScrollController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (_textScrollController.hasClients) {
      _textScrollController.animateTo(
        _textScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return '${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  bool _isAudioFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'].contains(ext);
  }

  Future<void> _openInFileExplorer(String filePath) async {
    final directory = p.dirname(filePath);
    final uri = Uri.directory(directory);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildOutputPathRow(String outputPath) {
    final fileName = p.basename(outputPath);
    final directory = p.dirname(outputPath);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 8),
              Text(
                'OUTPUT PATH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      directory,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Open in File Explorer',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openInFileExplorer(outputPath),
                    borderRadius: BorderRadius.circular(6),
                    hoverColor: Colors.white.withValues(alpha: 0.1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: Colors.deepPurple[200],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Show in Folder',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple[200],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processingState = ref.watch(processingStateProvider);

    // Auto-scroll to bottom when new logs arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (processingState.isProcessing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (processingState.error != null)
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      )
                    else
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                    const SizedBox(width: 16),
                    Text(
                      processingState.isProcessing
                          ? 'Processing...'
                          : processingState.error != null
                          ? 'Operation Failed'
                          : 'Operation Successful!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: processingState.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall Progress',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                Text(
                  '${(processingState.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FFMPEG LOGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                  ),
                ),
                if (processingState.logs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      final allLogs = LogFormatter.formatLogEntries(
                        processingState.logs,
                      );
                      Clipboard.setData(ClipboardData(text: allLogs));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text(
                      'Copy All',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 150,
                  maxHeight: 220,
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Theme(
                  data: ThemeData.dark(),
                  child: Scrollbar(
                    controller: _textScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _textScrollController,
                      itemCount: processingState.logs.length,
                      itemBuilder: (context, index) {
                        return LogEntryWidget(
                          entry: processingState.logs[index],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!processingState.isProcessing &&
                processingState.outputPath != null) ...[
              const Text(
                'PREVIEW RESULT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Center(
                  child: MediaPreviewPlayer(
                    path: processingState.outputPath!,
                    isVideo: !_isAudioFile(processingState.outputPath!),
                    onDurationAvailable: (duration) {
                      ref
                          .read(processingStateProvider.notifier)
                          .setOutputDuration(duration);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Output path - clickable to open in Finder/Explorer
              _buildOutputPathRow(processingState.outputPath!),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        processingState.isProcessing
                            ? 'Please do not close the application'
                            : 'You can now close this window',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                      if (!processingState.isProcessing &&
                          processingState.error == null &&
                          processingState.outputDuration != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Duration: ${_formatDuration(processingState.outputDuration!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!processingState.isProcessing)
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
