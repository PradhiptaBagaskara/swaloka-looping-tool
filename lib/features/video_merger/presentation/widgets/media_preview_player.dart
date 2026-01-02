import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Widget for previewing video/audio files with playback controls
class MediaPreviewPlayer extends StatefulWidget {
  const MediaPreviewPlayer({
    required this.path,
    super.key,
    this.isVideo = true,
  });
  final String path;
  final bool isVideo;

  @override
  State<MediaPreviewPlayer> createState() => _MediaPreviewPlayerState();
}

class _MediaPreviewPlayerState extends State<MediaPreviewPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(MediaPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _handlePathChange();
    }
  }

  void _handlePathChange() {
    _disposePlayer();
    setState(() {
      _initialized = false;
      _error = null;
    });
    _initPlayer();
  }

  void _initPlayer() {
    try {
      final controller = VideoPlayerController.file(File(widget.path));
      _controller = controller;

      controller.addListener(_onControllerUpdate);

      controller
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _initialized = true;
              });
              // Auto-play when preview opens (skip on Linux - not supported)
              if (!Platform.isLinux) {
                controller
                  ..setLooping(true)
                  ..play();
              }
            }
          })
          .catchError((Object error) {
            if (mounted) {
              setState(() {
                _error = error.toString();
              });
            }
          });
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize player: $e';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
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
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _seekTo(Duration position) {
    _controller?.seekTo(position);
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
              const Icon(
                Icons.error_outline,
                size: 24,
                color: Colors.redAccent,
              ),
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

    final controller = _controller;
    if (!_initialized || controller == null) {
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

    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final isPlaying = value.isPlaying;

    // Audio player - compact view
    if (!widget.isVideo) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Play/Pause button
            IconButton(
              iconSize: 48,
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.green,
              ),
              onPressed: _togglePlayPause,
            ),
            const SizedBox(width: 12),
            // Progress bar and time
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble(),
                      max: duration.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      activeColor: Colors.green,
                      inactiveColor: Colors.grey[700],
                      onChanged: (v) {
                        _seekTo(Duration(milliseconds: v.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Video player - full view with controls
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
          child: VideoPlayer(controller),
        ),
        // Play/Pause overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: AnimatedOpacity(
              opacity: isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: const ColoredBox(
                color: Colors.black26,
                child: Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
        // Progress bar at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.green,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
        ),
      ],
    );
  }
}
