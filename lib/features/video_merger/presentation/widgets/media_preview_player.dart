import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  Player? _player;
  VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(MediaPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      unawaited(_handlePathChange());
    }
  }

  Future<void> _handlePathChange() async {
    await _disposePlayer();
    _initialized = false;
    _initPlayer();
  }

  void _initPlayer() {
    try {
      final player = Player();
      _player = player;
      _videoController = VideoController(player);

      // Listen to player state and store subscriptions
      _subscriptions
        ..add(
          player.stream.position.listen((position) {
            if (mounted) {
              setState(() {
                _position = position;
              });
            }
          }),
        )
        ..add(
          player.stream.duration.listen((duration) {
            if (mounted) {
              setState(() {
                _duration = duration;
              });
            }
          }),
        )
        ..add(
          player.stream.playing.listen((playing) {
            if (mounted) {
              setState(() {
                _isPlaying = playing;
              });
            }
          }),
        );

      // Open the media file
      player
          .open(Media(widget.path))
          .then((_) {
            if (mounted) {
              setState(() {
                _initialized = true;
              });
              // Auto-play when preview opens
              player.play();
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
      // Player initialization failed (can happen in release builds)
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize player: $e';
        });
      }
    }
  }

  Future<void> _disposePlayer() async {
    // Cancel all stream subscriptions first
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Then dispose the player
    final player = _player;
    if (player != null) {
      try {
        await player.dispose();
      } on Exception catch (_) {
        // Ignore disposal errors (can happen on force close)
      }
    }
    _player = null;
    _videoController = null;
  }

  @override
  void dispose() {
    // Pause playback to help with cleanup on force close
    // Note: Using pause() instead of stop() for media_kit v1.x compatibility
    final player = _player;
    if (player != null) {
      try {
        player.pause();
      } on Exception catch (_) {
        // Ignore if player already disposed
      }
    }
    // Schedule async cleanup (won't complete on force close, but that's ok)
    unawaited(_disposePlayer());
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
    final player = _player;
    if (player == null) return;

    if (_isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }

  void _seekTo(Duration position) {
    _player?.seek(position);
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

    if (!_initialized || _videoController == null) {
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
      final position = _formatDuration(_position);
      final duration = _formatDuration(_duration);
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Play/Pause button
            IconButton(
              iconSize: 48,
              icon: Icon(
                _isPlaying
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
                      value: _position.inMilliseconds.toDouble(),
                      max: _duration.inMilliseconds.toDouble().clamp(
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
                          position,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          duration,
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

    // Video player - full view with built-in controls
    return Video(
      controller: _videoController!,
      // Built-in controls are used by default
    );
  }
}
