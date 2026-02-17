import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/utils/temp_directory_helper.dart';

/// Service for merging background video with sequential audio files
class VideoMergerService {
  String _formatPathForConcatFile(String path) {
    var safePath = p.normalize(path);
    if (Platform.isWindows) {
      safePath = safePath.replaceAll(r'\', '/');
    }
    return safePath.replaceAll("'", r"'\''");
  }

  Future<double?> _getAudioDurationSeconds(String audioPath) async {
    try {
      final result = await Process.run(
        FFmpegService.ffprobePath,
        [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          p.absolute(audioPath),
        ],
        environment: FFmpegService.extendedEnvironment,
      );
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return null;
      return double.tryParse(out);
    } on Exception catch (_) {
      return null;
    }
  }

  /// Check if audio file is already in AAC format based on extension
  /// .m4a and .aac files typically use AAC codec
  bool _isAudioAlreadyAAC(String audioPath) {
    final ext = p.extension(audioPath).toLowerCase();
    return ext == '.m4a' || ext == '.aac';
  }

  /// Check multiple audio files for AAC format
  /// Based on file extensions (.m4a, .aac)
  List<bool> _checkAudioFilesAAC(List<String> audioPaths) {
    return audioPaths.map(_isAudioAlreadyAAC).toList();
  }

  Future<List<String>> _normalizeAudioFilesToAacM4a({
    required List<String> audioFiles,
    required Directory tempDir,
    void Function(LogEntry log)? onLog,
  }) async {
    final log = LogEntry.info(
      'Checking ${audioFiles.length} audio file(s) for AAC format...',
    );
    onLog?.call(log);

    if (audioFiles.isEmpty) return [];

    // Check all files by extension
    final isAACResults = _checkAudioFilesAAC(audioFiles);

    // Separate files into already AAC vs needs conversion
    final alreadyAAC = <String>[];
    final needsConversion = <String>[];

    for (var i = 0; i < audioFiles.length; i++) {
      if (isAACResults[i]) {
        alreadyAAC.add(audioFiles[i]);
        log.addSubLog(
          LogEntry.info('✓ Already AAC: ${p.basename(audioFiles[i])}'),
        );
      } else {
        needsConversion.add(audioFiles[i]);
      }
    }

    final results = <String>[];

    // Add files that are already AAC (use original paths)
    results.addAll(alreadyAAC);

    // Convert files that need it
    if (needsConversion.isNotEmpty) {
      final convertLog = LogEntry.info(
        'Converting ${needsConversion.length} file(s) to AAC...',
      );
      log.addSubLog(convertLog);

      final converted = await _executeSingleRunFFmpeg(
        needsConversion,
        tempDir,
        alreadyAAC.length, // start index after already AAC files
        parentLog: convertLog,
      );

      results.addAll(converted.map((e) => e.path));

      convertLog.addSubLog(
        LogEntry.success(
          'Conversion complete: ${converted.length} file(s) processed',
        ),
      );
    }

    log.addSubLog(
      LogEntry.success(
        'Audio check complete: ${alreadyAAC.length} skipped, ${needsConversion.length} converted',
      ),
    );

    return results;
  }

  // Helper function to run one FFmpeg command for multiple files
  Future<List<({int index, String path})>> _executeSingleRunFFmpeg(
    List<String> inputs,
    Directory tempDir,
    int startIdx, {
    required LogEntry parentLog,
  }) async {
    final batchLog = LogEntry.info(
      'Processing batch of ${inputs.length} file(s) starting at index $startIdx...',
    );
    parentLog.addSubLog(batchLog);

    final args = ['-y'];

    // Add all inputs in this batch
    for (final path in inputs) {
      args.addAll(['-i', p.absolute(path)]);
    }

    final results = <({int index, String path})>[];

    // Map each input to its output
    for (var i = 0; i < inputs.length; i++) {
      final idx = startIdx + i;
      final outPath = p.join(tempDir.path, 'audio_part_$idx.m4a');

      args.addAll([
        '-map',
        '$i:a',
        '-vn',
        '-threads',
        '0',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        p.absolute(outPath),
      ]);

      results.add((index: idx, path: outPath));
    }

    await FFmpegService.run(
      args,
      errorMessage: 'Failed to process audio batch starting at index $startIdx',
      onLog: batchLog.addSubLog,
    );

    batchLog.addSubLog(
      LogEntry.success('Batch complete: ${inputs.length} file(s) processed'),
    );

    return results;
  }

  List<String> _buildAudioPlaylist(
    List<String> audioFiles,
    int audioLoopCount,
    void Function(LogEntry log)? onLog,
  ) {
    final processLog = LogEntry.info(
      'Building audio playlist from ${audioFiles.length} file(s)...',
    );
    onLog?.call(processLog);

    final orderedFiles = List<String>.from(audioFiles);
    final concatFiles = <String>[];

    // First iteration: Always use original order from UI
    // This ensures the first play through matches the user's intended sequence
    concatFiles.addAll(orderedFiles);

    if (audioLoopCount > 1) {
      // Subsequent iterations: Shuffle each time for variety
      // Example with 3 files and loopCount=3:
      //   Loop 1: [file1, file2, file3] <- original order
      //   Loop 2: [file2, file3, file1] <- shuffled
      //   Loop 3: [file3, file1, file2] <- shuffled again
      for (var loop = 1; loop < audioLoopCount; loop++) {
        final filesToConcat = List<String>.from(orderedFiles);
        filesToConcat.shuffle(Random());
        concatFiles.addAll(filesToConcat);
      }

      processLog.addSubLog(
        LogEntry.info(
          'Looping audio $audioLoopCount times (first loop: original order, subsequent loops: randomized)',
        ),
      );
    }

    processLog.addSubLog(
      LogEntry.success('Audio playlist ready (${concatFiles.length} item(s))'),
    );
    return concatFiles;
  }

  Future<String> _mergeAudioPlaylist(
    Directory tempDir,
    List<String> playlistFiles,
    void Function(LogEntry log)? onLog,
  ) async {
    final mergedAudioPath = p.join(tempDir.path, 'audio_merged.m4a');

    // Create parent log for merging operation
    final mergeLog = LogEntry.info('Concatenating audio playlist...');
    onLog?.call(mergeLog);

    if (playlistFiles.isEmpty) {
      throw Exception('No audio files to merge');
    }

    final concatListPath = p.join(tempDir.path, 'audio_concat.txt');
    final concatContent = playlistFiles
        .map((f) => "file '${_formatPathForConcatFile(f)}'")
        .join('\n');
    await File(concatListPath).writeAsString(concatContent);

    final cmd = <String>[
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      concatListPath,
      '-c',
      'copy',
      p.absolute(mergedAudioPath),
    ];

    await FFmpegService.run(
      cmd,
      errorMessage: 'Failed to merge audio tracks',
      onLog: mergeLog.addSubLog,
    );

    // Mark merge as complete
    mergeLog.addSubLog(
      LogEntry.success('Audio tracks merged successfully: $mergedAudioPath'),
    );

    return mergedAudioPath;
  }

  // Process audio files
  Future<String> _mergeVideoWithAudioFiles(
    String backgroundVideoPath,
    String outputPath,
    String mergedAudioPath,
    void Function(LogEntry log)? onLog,
  ) async {
    // 6. Fast mode: Loop video to match audio duration
    // -stream_loop -1 applies to next input (background video)
    // -shortest ensures we stop when audio ends

    // Create parent log for video merge operation
    final videoMergeLog = LogEntry.info('Merging video with audio...');
    onLog?.call(videoMergeLog);

    // Loop video to match audio duration (same approach as intro+background case)
    // Use hwaccel auto for hardware-accelerated decoding
    await FFmpegService.run(
      [
        '-y',
        '-stream_loop',
        '-1',
        '-i',
        p.absolute(backgroundVideoPath),
        '-i',
        p.absolute(mergedAudioPath),
        '-map',
        '0:v',
        '-map',
        '1:a',
        '-c:v',
        'copy',
        ...await FFmpegService.getStandardYouTubeVideoMetadataFlags(),
        '-c:a',
        'copy',
        '-shortest',
        '-movflags',
        '+faststart',
        p.absolute(outputPath),
      ],
      errorMessage: 'Failed to merge video with audio',
      onLog: videoMergeLog.addSubLog,
    );

    return outputPath;
  }

  Future<String> processVideoWithAudio({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    required String projectRootPath,
    int audioLoopCount = 1,
    String? introVideoPath,
    bool enableParallelProcessing = true,
    void Function(double progress)? onProgress,
    void Function(LogEntry log)? onLog,
  }) async {
    await FFmpegService.verifyInstallation(onLog);
    onProgress?.call(0.1);

    final tempDir = await TempDirectoryHelper.create(
      fallbackBasePath: projectRootPath,
      prefix: 'swaloka_merger',
      onLog: onLog,
    );
    try {
      final String mergedAudioPath;

      // 1) Audio pipeline - Always use AAC normalization
      onLog?.call(
        LogEntry.info('Audio pipeline: AAC normalize'),
      );
      final playlistFiles = _buildAudioPlaylist(
        await _normalizeAudioFilesToAacM4a(
          audioFiles: audioFiles,
          tempDir: tempDir,
          onLog: onLog,
        ),
        audioLoopCount,
        onLog,
      );
      onProgress?.call(0.3);
      mergedAudioPath = await _mergeAudioPlaylist(
        tempDir,
        playlistFiles,
        onLog,
      );
      onProgress?.call(0.5);

      // If no intro, output directly to final path
      if (introVideoPath == null) {
        await _mergeVideoWithAudioFiles(
          backgroundVideoPath,
          outputPath,
          mergedAudioPath,
          onLog,
        );
      } else {
        // If intro exists: Split audio, create intro+background separately, then concat
        final log = LogEntry.info(
          'Creating video with intro and playlist audio from start...',
        );
        onLog?.call(log);

        // Get intro and audio durations
        var introSeconds = 0.0;
        try {
          final introMeta = await FFmpegService.getVideoMetadata(
            introVideoPath,
          );
          if (introMeta.duration != null) {
            introSeconds = introMeta.duration!.inMilliseconds / 1000.0;
          }
        } on Exception catch (_) {}

        final audioSeconds = await _getAudioDurationSeconds(mergedAudioPath);
        if (audioSeconds == null || audioSeconds <= 0) {
          throw Exception('Could not determine audio duration');
        }

        final remainingAudioSeconds = audioSeconds - introSeconds;

        // Step 1: Split playlist audio into intro part and remaining part
        final audioIntroPart = p.join(tempDir.path, 'audio_intro_part.m4a');
        final audioRemainingPart = p.join(
          tempDir.path,
          'audio_remaining_part.m4a',
        );

        final splitLog = LogEntry.info('Splitting playlist audio...');
        log.addSubLog(splitLog);

        // Extract first part (for intro duration)
        await FFmpegService.run(
          [
            '-y',
            '-hwaccel',
            'auto',
            '-i',
            p.absolute(mergedAudioPath),
            '-t',
            introSeconds.toStringAsFixed(3),
            '-c',
            'copy',
            p.absolute(audioIntroPart),
          ],
          errorMessage: 'Failed to extract intro audio part',
          onLog: splitLog.addSubLog,
        );

        // Extract remaining part
        await FFmpegService.run(
          [
            '-y',
            '-hwaccel',
            'auto',
            '-i',
            p.absolute(mergedAudioPath),
            '-ss',
            introSeconds.toStringAsFixed(3),
            '-c',
            'copy',
            p.absolute(audioRemainingPart),
          ],
          errorMessage: 'Failed to extract remaining audio part',
          onLog: splitLog.addSubLog,
        );

        onProgress?.call(0.6);

        // Step 2: Create intro video with first audio part
        final introWithAudioPath = p.join(tempDir.path, 'intro_with_audio.mp4');

        final introLog = LogEntry.info('Creating intro with audio...');
        log.addSubLog(introLog);

        await FFmpegService.run(
          [
            '-y',
            '-i',
            p.absolute(introVideoPath),
            '-i',
            p.absolute(audioIntroPart),
            '-map',
            '0:v',
            '-map',
            '1:a',
            '-c:v',
            'copy',
            ...await FFmpegService.getStandardYouTubeVideoMetadataFlags(),
            '-c:a',
            'copy',
            '-shortest',
            '-movflags',
            '+faststart',
            p.absolute(introWithAudioPath),
          ],
          errorMessage: 'Failed to create intro with audio',
          onLog: introLog.addSubLog,
        );

        onProgress?.call(0.7);

        // Step 3: Create background video with remaining audio
        final backgroundWithAudioPath = p.join(
          tempDir.path,
          'background_with_audio.mp4',
        );

        final bgLog = LogEntry.info(
          'Creating background with remaining audio (${remainingAudioSeconds.toStringAsFixed(1)}s)...',
        );
        log.addSubLog(bgLog);

        await FFmpegService.run(
          [
            '-y',
            '-stream_loop',
            '-1',
            '-i',
            p.absolute(backgroundVideoPath),
            '-i',
            p.absolute(audioRemainingPart),
            '-map',
            '0:v',
            '-map',
            '1:a',
            '-c:v',
            'copy',
            ...await FFmpegService.getStandardYouTubeVideoMetadataFlags(),
            '-c:a',
            'copy',
            '-shortest',
            '-movflags',
            '+faststart',
            p.absolute(backgroundWithAudioPath),
          ],
          errorMessage: 'Failed to create background with audio',
          onLog: bgLog.addSubLog,
        );

        onProgress?.call(0.8);

        // Step 4: Concat intro + background (both have video+audio)
        final concatLog = LogEntry.info(
          'Concatenating intro with background...',
        );
        log.addSubLog(concatLog);

        final concatListPath = p.join(tempDir.path, 'concat_list.txt');
        final concatContent = [
          "file '${_formatPathForConcatFile(introWithAudioPath)}'",
          "file '${_formatPathForConcatFile(backgroundWithAudioPath)}'",
        ].join('\n');
        await File(concatListPath).writeAsString(concatContent);

        await FFmpegService.run(
          [
            '-y',
            '-f',
            'concat',
            '-safe',
            '0',
            '-i',
            concatListPath,
            '-c',
            'copy',
            p.absolute(outputPath),
          ],
          errorMessage: 'Failed to concat intro with background',
          onLog: concatLog.addSubLog,
        );
        concatLog.addSubLog(LogEntry.success('Final video created'));
      }

      onProgress?.call(1);
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
}
