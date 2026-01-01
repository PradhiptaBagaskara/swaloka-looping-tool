import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription> _subscriptions = [];
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
      _disposePlayer();
      _initialized = false;
      _initPlayer();
    }
  }

  void _initPlayer() {
    _player = Player();
    _videoController = VideoController(_player);

    // Listen to player state and store subscriptions
    _subscriptions.add(
      _player.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      }),
    );

    _subscriptions.add(
      _player.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      }),
    );

    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
          });
        }
      }),
    );

    // Open the media file
    _player
        .open(Media(widget.path))
        .then((_) {
          if (mounted) {
            setState(() {
              _initialized = true;
            });
            // Auto-play when preview opens
            _player.play();
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

  Future<void> _disposePlayer() async {
    // Cancel all stream subscriptions first
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Then dispose the player
    await _player.dispose();
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
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekTo(Duration position) {
    _player.seek(position);
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
      controller: _videoController,
      // Built-in controls are used by default
    );
  }
}
