import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Simplified audio player widget for audio overlay items
/// Designed specifically for the audio tools page with real-time volume control
///
/// Preview behavior:
/// - Each overlay has its own independent player controller
/// - Multiple overlays can play simultaneously (allowing users to preview how they sound mixed together)
/// - Each overlay maintains its own volume level during preview
///
/// Note: This is a preview player. The actual audio mixing/processing will be done by FFmpeg
/// when the user clicks "Process Audio".
class AudioOverlayPlayer extends StatefulWidget {
  const AudioOverlayPlayer({
    required this.path,
    required this.volume,
    required this.onPlaybackComplete,
    this.onPlayingStateChanged,
    super.key,
  });

  final String path;
  final double volume;
  final VoidCallback onPlaybackComplete;
  final void Function(bool isPlaying)? onPlayingStateChanged;

  @override
  State<AudioOverlayPlayer> createState() => _AudioOverlayPlayerState();
}

class _AudioOverlayPlayerState extends State<AudioOverlayPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;

    controller.addListener(_onControllerUpdate);

    controller
        .initialize()
        .then((_) {
          if (mounted) {
            // Set volume
            controller.setVolume(widget.volume);
            // Set looping
            controller.setLooping(true);

            // Mark as initialized, but don't sync playing state
            // The parent controls whether this should be playing or not
            setState(() {
              _initialized = true;
            });
            // Don't notify parent during initialization - parent already knows the state
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() {
              _initialized = true; // Still mark as initialized to show error
            });
          }
        });
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final position = controller.value.position;
      final duration = controller.value.duration;

      // Check if playback completed
      if (duration > Duration.zero &&
          position >= duration &&
          controller.value.isPlaying) {
        widget.onPlaybackComplete();
      }
    }

    // Update playing state from controller
    if (_controller != null) {
      final newIsPlaying = _controller!.value.isPlaying;
      if (_isPlaying != newIsPlaying) {
        setState(() {
          _isPlaying = newIsPlaying;
        });
        // Notify parent of state change
        widget.onPlayingStateChanged?.call(newIsPlaying);
      }
    }
  }

  @override
  void didUpdateWidget(AudioOverlayPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle path change
    if (oldWidget.path != widget.path) {
      _disposePlayer();
      setState(() {
        _initialized = false;
        _isPlaying = false;
      });
      _initPlayer();
    }
    // Handle volume change - update without interrupting playback
    else if (oldWidget.volume != widget.volume) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        controller.setVolume(widget.volume);
      }
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final newState = !_isPlaying;

    setState(() {
      if (newState) {
        controller.play();
        _isPlaying = true;
      } else {
        controller.pause();
        _isPlaying = false;
      }
    });

    // Notify parent of state change
    widget.onPlayingStateChanged?.call(newState);
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_initialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Play/Pause button - compact
          InkWell(
            onTap: _togglePlayPause,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 32,
              color: _isPlaying
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          // Progress bar and time
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
                  controller.seekTo(Duration(milliseconds: v.toInt()));
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Time display - compact
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
    );
  }
}
