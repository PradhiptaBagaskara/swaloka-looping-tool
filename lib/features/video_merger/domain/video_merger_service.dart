import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

/// Media information extracted from ffprobe
class MediaInfo {
  final int width;
  final int height;
  final String? videoCodec;
  final String? audioCodec;
  final int? audioBitrate;
  final int? audioSampleRate;

  MediaInfo({
    required this.width,
    required this.height,
    this.videoCodec,
    this.audioCodec,
    this.audioBitrate,
    this.audioSampleRate,
  });

  /// Check if video needs re-encoding for given parameters
  bool needsVideoEncoding({
    required int targetWidth,
    required int targetHeight,
    required bool needsScaleOrPad,
  }) {
    // Re-encode if resolution changes or if scaling/padding is needed
    if (width != targetWidth || height != targetHeight) return true;
    if (needsScaleOrPad) return true;
    return false;
  }

  /// Check if audio needs re-encoding
  bool needsAudioEncoding({
    required int targetBitrate,
    required int targetSampleRate,
    required bool isSingleFile,
  }) {
    // If single file, check if matches target
    if (isSingleFile) {
      final matchesCodec = audioCodec?.toLowerCase() == 'aac';
      final matchesBitrate =
          (audioBitrate ?? 0) >= targetBitrate * 900; // Allow some tolerance
      final matchesSampleRate = (audioSampleRate ?? 0) == targetSampleRate;
      return !(matchesCodec && matchesBitrate && matchesSampleRate);
    }
    // Multiple files always need encoding (merging)
    return true;
  }
}

/// Service for merging background video with sequential audio files
class VideoMergerService {
  /// Merge background video with multiple audio files
  ///
  /// [backgroundVideoPath] - Path to background video file
  /// [audioFiles] - List of audio/video file paths (audio will be extracted from videos)
  /// [outputPath] - Path where final merged video will be saved
  /// [title] - Video title metadata
  /// [author] - Video author metadata
  /// [comment] - Video comment metadata
  /// [useGpu] - Whether to use GPU acceleration
  /// [selectedEncoder] - Specific encoder to use (null for auto-detect)
  /// [avoidReencoding] - If true, skip re-encoding when not needed (faster, no quality loss)
  /// [concurrencyLimit] - Maximum number of parallel audio processing tasks
  /// [audioLoopCount] - Number of times to loop and randomize audio
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  /// [onLog] - Callback for real-time FFmpeg logs
  /// [loopCount] - Loop count to use for output filename prefix
  ///
  /// Returns: path to merged video file
  Future<String> mergeVideoWithAudio({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    String? title,
    String? author,
    String? comment,
    bool useGpu = true,
    String? selectedEncoder,
    bool avoidReencoding = true,
    int concurrencyLimit = 4,
    int audioLoopCount = 1,
    List<String> extraFlags = const [],
    void Function(double progress)? onProgress,
    void Function(String log)? onLog,
  }) async {
    try {
      // Use system FFmpeg CLI on all platforms for consistent behavior
      return _mergeVideoWithAudio(
        backgroundVideoPath: backgroundVideoPath,
        audioFiles: audioFiles,
        outputPath: outputPath,
        title: title,
        author: author,
        comment: comment,
        concurrencyLimit: concurrencyLimit,
        audioLoopCount: audioLoopCount,
        extraFlags: extraFlags,
        onProgress: onProgress,
        onLog: onLog,
      );
    } catch (e) {
      throw Exception('Failed to merge video: $e');
    }
  }
}

/// Implementation using FFmpeg CLI directly - works on all platforms
/// Always uses fast mode: copy video stream, infinite loop, -shortest
/// If audioLoopCount > 1, shuffles audio order for each loop iteration
Future<String> _mergeVideoWithAudio({
  required String backgroundVideoPath,
  required List<String> audioFiles,
  required String outputPath,
  String? title,
  String? author,
  String? comment,
  int concurrencyLimit = 4,
  int audioLoopCount = 1,
  List<String> extraFlags = const [],
  void Function(double progress)? onProgress,
  void Function(String log)? onLog,
}) async {
  /// Helper function to run FFmpeg command and stream output to onLog
  Future<void> runFFmpegWithLogging(
    List<String> command, {
    String? errorMessage,
  }) async {
    onLog?.call('Command: ffmpeg ${command.join(" ")}');

    final process = await Process.start('ffmpeg', command);

    // Stream stdout
    process.stdout.transform(utf8.decoder).listen((line) {
      onLog?.call(line.trim());
    });

    // Stream stderr (FFmpeg uses stderr for progress/info)
    process.stderr.transform(utf8.decoder).listen((line) {
      onLog?.call(line.trim());
    });

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception(errorMessage ?? 'FFmpeg command failed');
    }
  }
  // 1. Verify ffmpeg exists
  try {
    final check = await Process.run('ffmpeg', ['-version']);
    if (check.exitCode != 0) throw Exception('FFmpeg not found');
  } catch (e) {
    throw Exception(
      'FFmpeg CLI not found. Please install FFmpeg and add it to your System PATH.',
    );
  }

  onLog?.call('Using FFmpeg CLI for all platforms');

  // 2. Prepare temp directory
  final tempDir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final tempAudioDir = Directory('${tempDir.path}/swaloka_temp_$timestamp');
  await tempAudioDir.create(recursive: true);

  try {
    // 3. Extract audio from each file in parallel
    final extractedFiles = <String>[];
    for (int i = 0; i < audioFiles.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < audioFiles.length)
          ? i + concurrencyLimit
          : audioFiles.length;
      final batch = audioFiles.sublist(i, end);

      await Future.wait(
        batch.asMap().entries.map((entry) async {
          final idx = i + entry.key;
          final inputPath = entry.value;
          final outPath = '${tempAudioDir.path}/part_$idx.aac';

          await runFFmpegWithLogging([
            '-y',
            '-i',
            inputPath,
            '-vn',
            '-acodec',
            'aac',
            '-ar',
            '44100',
            '-ac',
            '2',
            '-b:a',
            '192k',
            outPath,
          ], errorMessage: 'Failed to extract audio from $inputPath');
          extractedFiles.add(outPath);
        }),
      );
      onProgress?.call((i / audioFiles.length) * 0.4);
    }

    // 4. Concat audio files (with looping support)
    final concatFilePath = '${tempAudioDir.path}/concat.txt';
    final concatFiles = <String>[];

    if (audioLoopCount == 1) {
      // Single pass - use files as-is
      concatFiles.addAll(extractedFiles);
    } else {
      // Multiple passes - shuffle for each iteration
      for (int loop = 0; loop < audioLoopCount; loop++) {
        final filesToConcat = List<String>.from(extractedFiles);
        filesToConcat.shuffle(Random());
        concatFiles.addAll(filesToConcat);
      }
      onLog?.call(
        'Looping audio $audioLoopCount times with randomized order per loop',
      );
    }

    final concatContent = concatFiles
          .map((f) => "file '${f.replaceAll("'", "'\\''")}'")
          .join('\n');
    await File(concatFilePath).writeAsString(concatContent);

    final mergedAudioPath = '${tempAudioDir.path}/merged.aac';
    onLog?.call('Merging audio tracks...');
    await runFFmpegWithLogging([
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      concatFilePath,
      '-c',
      'copy',
      mergedAudioPath,
    ], errorMessage: 'Failed to merge audio tracks');
    onProgress?.call(0.5);

    // 5. Build metadata flags if provided
    final metadataFlags = <String>[];
    if (title != null) {
      metadataFlags.addAll(['-metadata', 'title=$title']);
    }
    if (author != null) {
      metadataFlags.addAll(['-metadata', 'artist=$author']);
    }
    if (comment != null) {
      metadataFlags.addAll(['-metadata', 'comment=$comment']);
    }

    // 6. Fast mode: Loop video to match audio duration
    // -stream_loop -1 applies to next input (background video)
    // -shortest ensures we stop when audio ends
    onLog?.call('Starting fast merge...');

    // Build optimized FFmpeg command
    final command = [
      '-stream_loop',
      '-1',
      '-i',
      backgroundVideoPath,
      '-i',
      mergedAudioPath,
      '-map',
      '0:v',
      '-map',
      '1:a',
      '-c:v',
      'copy',
      '-c:a',
      'copy',
      '-shortest',
      ...metadataFlags,
      outputPath,
      '-y',
    ];

    onLog?.call('Starting fast merge...');

    await runFFmpegWithLogging(command, errorMessage: 'Failed to merge video');

    onProgress?.call(1.0);
    onLog?.call('Process complete! Output: $outputPath');
    return outputPath;
  } finally {
    // Cleanup
    if (await tempAudioDir.exists()) {
      await tempAudioDir.delete(recursive: true);
    }
  }
}
