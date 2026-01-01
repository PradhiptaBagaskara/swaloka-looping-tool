import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';

/// Service for merging background video with sequential audio files
class VideoMergerService {

  // create temp directory in project folder
  Future<Directory> _createTempDirectory(
    String projectRootPath,
    void Function(LogEntry log)? onLog,
  ) async {
    onLog?.call(LogEntry.info('Creating temp directory...'));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory(
      p.join(projectRootPath, 'temp', 'swaloka_temp_$timestamp'),
    );
    await tempDir.create(recursive: true);
    onLog?.call(LogEntry.success('Temp directory created: ${tempDir.path}'));
    return tempDir;
  }

  // Concat audio files
  Future<String> _concatAudioFiles(
    List<String> audioFiles,
    Directory tempDir,
    int audioLoopCount,
    int concurrencyLimit,
    void Function(LogEntry log)? onLog,
  ) async {
    final processLog = LogEntry.info(
      'Processing ${audioFiles.length} audio file(s)...',
    );
    onLog?.call(processLog);

    final extractedFiles = <String>[];
    for (int i = 0; i < audioFiles.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < audioFiles.length)
          ? i + concurrencyLimit
          : audioFiles.length;
      final batch = audioFiles.sublist(i, end);

      final batchLog = LogEntry.info(
        'Extracting audio batch ${(i ~/ concurrencyLimit) + 1}...',
      );
      processLog.addSubLog(batchLog);

      await Future.wait(
        batch.asMap().entries.map((entry) async {
          final idx = i + entry.key;
          final inputPath = entry.value;
          final outPath = p.join(tempDir.path, 'audio_part_$idx.aac');

          await FFmpegService.run(
            [
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
            ],
            errorMessage: 'Failed to extract audio from $inputPath',
            onLog: (log) => batchLog.addSubLog(log),
          );
          extractedFiles.add(outPath);
        }),
      );
    }
    final concatFilePath = p.join(tempDir.path, 'audio_concat.txt');
    final concatFiles = <String>[];

    // First iteration: Always use original order from UI
    // This ensures the first play through matches the user's intended sequence
    concatFiles.addAll(extractedFiles);

    if (audioLoopCount > 1) {
      // Subsequent iterations: Shuffle each time for variety
      // Example with 3 files and loopCount=3:
      //   Loop 1: [file1, file2, file3] <- original order
      //   Loop 2: [file2, file3, file1] <- shuffled
      //   Loop 3: [file3, file1, file2] <- shuffled again
      for (int loop = 1; loop < audioLoopCount; loop++) {
        final filesToConcat = List<String>.from(extractedFiles);
        filesToConcat.shuffle(Random());
        concatFiles.addAll(filesToConcat);
      }

      // Add looping info as sublog
      processLog.addSubLog(
        LogEntry.info(
          'Looping audio $audioLoopCount times (first loop: original order, subsequent loops: randomized)',
        ),
      );
    }

    final concatContent = concatFiles
        .map((f) => "file '${f.replaceAll("'", "'\\''")}'")
        .join('\n');
    await File(concatFilePath).writeAsString(concatContent);

    // Mark processing as complete
    processLog.addSubLog(LogEntry.success('Audio processing completed'));

    return concatFilePath;
  }

  // Merge audio files
  Future<String> _mergeAudioFiles(
    Directory tempDir,
    String concatFilePath,
    void Function(LogEntry log)? onLog,
  ) async {
    final mergedAudioPath = p.join(tempDir.path, 'audio_merged.aac');

    // Create parent log for merging operation
    final mergeLog = LogEntry.info('Merging audio tracks...');
    onLog?.call(mergeLog);

    await FFmpegService.run(
      [
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
      ],
      errorMessage: 'Failed to merge audio tracks',
      onLog: (log) => mergeLog.addSubLog(log),
    );

    // Mark merge as complete
    mergeLog.addSubLog(
      LogEntry.success('Audio tracks merged successfully: $mergedAudioPath'),
    );

    return mergedAudioPath;
    // end of _mergeAudioFiles
  }

  // Process audio files
  Future<String> _mergeVideoWithAudioFiles(
    String backgroundVideoPath,
    String outputPath,
    String mergedAudioPath,
    List<String> metadataFlags,
    void Function(LogEntry log)? onLog,
  ) async {
    // 6. Fast mode: Loop video to match audio duration
    // -stream_loop -1 applies to next input (background video)
    // -shortest ensures we stop when audio ends

    // Create parent log for video merge operation
    final videoMergeLog = LogEntry.info('Merging video with audio...');
    onLog?.call(videoMergeLog);

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

    await FFmpegService.run(
      command,
      errorMessage: 'Failed to merge video',
      onLog: (log) => videoMergeLog.addSubLog(log),
    );

    // Mark merge as complete
    videoMergeLog.addSubLog(
      LogEntry.success('Video merge complete! Output: $outputPath'),
    );

    return outputPath;
    // end of _mergeVideoWithAudioFiles
  }

  Future<String> processVideoWithAudio({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    required String projectRootPath,
    String? title,
    String? author,
    String? comment,
    int concurrencyLimit = 4,
    int audioLoopCount = 1,
    void Function(double progress)? onProgress,
    void Function(LogEntry log)? onLog,
  }) async {
    await FFmpegService.verifyInstallation(onLog);
    onProgress?.call(0.2);
    final tempDir = await _createTempDirectory(projectRootPath, onLog);
    try {
      final concatFilePath = await _concatAudioFiles(
        audioFiles,
        tempDir,
        audioLoopCount,
        concurrencyLimit,
        onLog,
      );
      onProgress?.call(0.4);
      final mergedAudioPath = await _mergeAudioFiles(
        tempDir,
        concatFilePath,
        onLog,
      );
      onProgress?.call(0.6);
      final metadataFlags = _buildMetadataFlags(title, author, comment);
      await _mergeVideoWithAudioFiles(
        backgroundVideoPath,
        outputPath,
        mergedAudioPath,
        metadataFlags,
        onLog,
      );
      onProgress?.call(1.0);
      onLog?.call(
        LogEntry.success('Video merge complete! Output: $outputPath'),
      );
      return outputPath;
    } finally {
      // Cleanup
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  // Build metadata flags
  List<String> _buildMetadataFlags(
    String? title,
    String? author,
    String? comment,
  ) {
    final metadataFlags = <String>[];
    if (title != null) {
      metadataFlags.addAll(['-metadata', 'title=$title']);
    }
    if (author != null) {
      // depending on the platform/ffmpeg installation it might accept artist or author. So we add both.
      metadataFlags.addAll(['-metadata', 'artist=$author']);
      metadataFlags.addAll(['-metadata', 'author=$author']);
    }
    if (comment != null) {
      metadataFlags.addAll(['-metadata', 'comment=$comment']);
    }
    return metadataFlags;
  }

  // end close of class VideoMergerService
}
