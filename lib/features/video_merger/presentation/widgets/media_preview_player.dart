import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Widget for previewing video/audio files with playback controls
class MediaPreviewPlayer extends StatefulWidget {
  final String path;
  final bool isVideo;

  const MediaPreviewPlayer({
    super.key,
    required this.path,
    this.isVideo = true,
  });

  @override
  State<MediaPreviewPlayer> createState() => _MediaPreviewPlayerState();
}

class _MediaPreviewPlayerState extends State<MediaPreviewPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(MediaPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller.dispose();
      _initialized = false;
      _initController();
    }
  }

  void _initController() {
    _controller = VideoPlayerController.file(File(widget.path));
    _controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _initialized = true;
            });
            // Auto-play when preview opens
            _controller.play();
          }
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
            });
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 24, color: Colors.redAccent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Unable to play this file',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Audio player - compact view
    if (!widget.isVideo) {
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, value, child) {
          final position = _formatDuration(value.position);
          final duration = _formatDuration(value.duration);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Play/Pause button
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.green,
                  ),
                  onPressed: () {
                    setState(() {
                      value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                ),
                const SizedBox(width: 12),
                // Progress bar and time
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: value.position.inMilliseconds.toDouble(),
                          max: value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                          activeColor: Colors.green,
                          inactiveColor: Colors.grey[700],
                          onChanged: (v) {
                            _controller.seekTo(Duration(milliseconds: v.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(position, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            Text(duration, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Video player - full view
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                // Play/Pause overlay
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                    child: AnimatedOpacity(
                      opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Controls
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black,
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              final position = _formatDuration(value.position);
              final duration = _formatDuration(value.duration);
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                  ),
                  Text(position, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: value.position.inMilliseconds.toDouble(),
                        max: value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                        activeColor: Colors.blue,
                        inactiveColor: Colors.grey[700],
                        onChanged: (v) {
                          _controller.seekTo(Duration(milliseconds: v.toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(duration, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
