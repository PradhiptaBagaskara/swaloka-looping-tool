import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/video_merger_page.dart';

class MergeProgressDialog extends ConsumerStatefulWidget {
  const MergeProgressDialog({super.key});

  @override
  ConsumerState<MergeProgressDialog> createState() => _MergeProgressDialogState();
}

class _MergeProgressDialogState extends ConsumerState<MergeProgressDialog> {
  final ScrollController _scrollController = ScrollController();
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
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final processingState = ref.watch(processingStateProvider);

    // Determine if there's an error
    final hasError = processingState.error != null;
    final isProcessing = processingState.isProcessing;
    final isCompleted = !isProcessing && processingState.outputPath != null;

    // Status text and icon
    String statusText;
    IconData? statusIcon;

    if (hasError) {
      statusText = 'Export Failed!';
      statusIcon = Icons.error_outline;
    } else if (isCompleted) {
      statusText = 'Export Successful!';
      statusIcon = Icons.check_circle_outline;
    } else {
      statusText = 'Generating Video Output...';
      statusIcon = null; // No icon when processing
    }

    // Auto-scroll to bottom when new logs arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
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
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 20)
                    else
                      const Icon(Icons.check_circle_outline,
                          color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 16),
                    Text(
                      processingState.isProcessing
                          ? 'Generating Video Output...'
                          : processingState.error != null
                              ? 'Export Failed'
                              : 'Export Successful!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
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
            Text(
              'FFMPEG LOGS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 250,
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
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: processingState.logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          processingState.logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFFCCCCCC),
                          ),
                        ),
                      );
                    },
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
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Center(
                  child: MediaPreviewPlayer(
                    path: processingState.outputPath!,
                    isVideo: true,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  processingState.isProcessing
                      ? 'Please do not close the application'
                      : 'You can now close this window',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
