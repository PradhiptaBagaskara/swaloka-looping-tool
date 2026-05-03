import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/data/bulk_loop_job_repository.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/models/models.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/video_merger_service.dart';

bool _bulkLoopExecutorCancelRequested = false;
bool _bulkLoopExecutorIsRunning = false;

class BulkLoopExecutorService {
  BulkLoopExecutorService({
    required BulkLoopJobRepository repository,
    required VideoMergerService mergerService,
  }) : _repository = repository,
       _mergerService = mergerService;

  final BulkLoopJobRepository _repository;
  final VideoMergerService _mergerService;

  bool get isRunning => _bulkLoopExecutorIsRunning;

  Future<void> requestCancelAll({void Function(LogEntry log)? onLog}) async {
    _bulkLoopExecutorCancelRequested = true;
    onLog?.call(
      LogEntry.warning(
        'Stop requested by user. Cancelling active FFmpeg process...',
      ),
    );
    await FFmpegService.cancel();
  }

  Future<BulkLoopJob> runBatch(
    BulkLoopJob job, {
    void Function(double progress)? onProgress,
    void Function(LogEntry log)? onLog,
  }) async {
    if (_bulkLoopExecutorIsRunning) {
      onLog?.call(
        LogEntry.warning(
          'Batch lain sedang berjalan. Proses bulk loop dijalankan 1 per 1.',
        ),
      );
      return job;
    }
    _bulkLoopExecutorIsRunning = true;
    _bulkLoopExecutorCancelRequested = false;
    try {
      var runningJob = job.copyWith(status: BulkLoopJobStatus.running);
      await _repository.save(runningJob);
      onLog?.call(
        LogEntry.info(
          'Running bulk processing queue (sequential, dynamic ready pickup).',
        ),
      );

      while (true) {
        if (_bulkLoopExecutorCancelRequested) {
          onLog?.call(
            LogEntry.warning('Bulk processing stopped by user request.'),
          );
          break;
        }

        final latestJob = await _repository.load(
          projectRootPath: job.projectRootPath,
          jobId: job.id,
        );
        if (latestJob != null) {
          runningJob = latestJob.copyWith(status: BulkLoopJobStatus.running);
        }

        final readyQueue =
            runningJob.contents
                .where(
                  (content) =>
                      content.status == BulkLoopContentStatus.queued &&
                      content.backgroundVideoPath != null,
                )
                .toList()
              ..sort((a, b) => a.index.compareTo(b.index));

        if (readyQueue.isEmpty) {
          onLog?.call(
            LogEntry.info('Queue empty: no more queued item to process.'),
          );
          break;
        }

        final content = readyQueue.first;
        final backgroundVideoPath = content.backgroundVideoPath;
        if (backgroundVideoPath == null || backgroundVideoPath.isEmpty) {
          runningJob = await _saveContentUpdate(
            runningJob,
            content.copyWith(
              status: BulkLoopContentStatus.pendingMedia,
              error: 'Background video is missing',
            ),
          );
          continue;
        }

        final audioById = <String, BulkLoopAudioItem>{
          for (final audio in runningJob.audioItems) audio.id: audio,
        };
        final audioPaths = content.audioItemIds
            .map((audioId) => audioById[audioId]?.path)
            .whereType<String>()
            .toList();
        if (audioPaths.isEmpty) {
          runningJob = await _saveContentUpdate(
            runningJob,
            content.copyWith(
              status: BulkLoopContentStatus.failed,
              error: 'No mapped audio files',
            ),
          );
          continue;
        }

        final runningContent = content.copyWith(
          status: BulkLoopContentStatus.running,
          processedAt: DateTime.now(),
          clearError: true,
          clearFinishedAt: true,
        );
        runningJob = await _saveContentUpdate(runningJob, runningContent);

        final outputPath = _buildOutputPath(job, content);
        try {
          await _mergerService.processVideoWithAudio(
            backgroundVideoPath: backgroundVideoPath,
            audioFiles: audioPaths,
            outputPath: outputPath,
            projectRootPath: job.projectRootPath,
            audioLoopCount: job.loopCount,
            introVideoPath: content.introVideoPath,
            enableParallelProcessing: false,
            onLog: onLog,
          );

          runningJob = await _saveContentUpdate(
            runningJob,
            content.copyWith(
              status: BulkLoopContentStatus.done,
              outputPath: outputPath,
              finishedAt: DateTime.now(),
              clearError: true,
            ),
          );
        } on Exception catch (error) {
          if (_bulkLoopExecutorCancelRequested) {
            runningJob = await _saveContentUpdate(
              runningJob,
              content.copyWith(
                status: BulkLoopContentStatus.failed,
                error: 'Cancelled by user',
                finishedAt: DateTime.now(),
              ),
            );
            onLog?.call(
              LogEntry.warning(
                'Current item stopped because user requested cancel.',
              ),
            );
            break;
          }
          runningJob = await _saveContentUpdate(
            runningJob,
            content.copyWith(
              status: BulkLoopContentStatus.failed,
              error: error.toString(),
              finishedAt: DateTime.now(),
            ),
          );
        }
        onProgress?.call(_calculateQueueProgress(runningJob));
      }

      final doneCount = runningJob.contents
          .where((content) => content.status == BulkLoopContentStatus.done)
          .length;
      final failedCount = runningJob.contents
          .where((content) => content.status == BulkLoopContentStatus.failed)
          .length;
      final totalCount = runningJob.contents.length;

      final nextStatus = doneCount == totalCount
          ? BulkLoopJobStatus.completed
          : doneCount > 0
          ? BulkLoopJobStatus.partiallyDone
          : failedCount > 0
          ? BulkLoopJobStatus.failed
          : BulkLoopJobStatus.ready;

      final finalJob = runningJob.copyWith(status: nextStatus);
      await _repository.save(finalJob);
      return finalJob;
    } finally {
      _bulkLoopExecutorIsRunning = false;
    }
  }

  double _calculateQueueProgress(BulkLoopJob job) {
    final processable = job.contents
        .where(
          (content) =>
              content.backgroundVideoPath != null &&
              content.audioItemIds.isNotEmpty,
        )
        .toList();
    if (processable.isEmpty) return 0;
    final finished = processable
        .where(
          (content) =>
              content.status == BulkLoopContentStatus.done ||
              content.status == BulkLoopContentStatus.failed,
        )
        .length;
    final activeQueue = processable
        .where(
          (content) =>
              content.status == BulkLoopContentStatus.queued ||
              content.status == BulkLoopContentStatus.running,
        )
        .length;
    final denominator = finished + activeQueue;
    if (denominator <= 0) return 0;
    return finished / denominator;
  }

  BulkLoopJob _updateContent(
    BulkLoopJob job,
    BulkLoopContentPlan updatedContent,
  ) {
    final nextContents = job.contents
        .map(
          (content) =>
              content.id == updatedContent.id ? updatedContent : content,
        )
        .toList();
    return job.copyWith(contents: nextContents);
  }

  Future<BulkLoopJob> _saveContentUpdate(
    BulkLoopJob currentJob,
    BulkLoopContentPlan updatedContent,
  ) async {
    final latestJob = await _repository.load(
      projectRootPath: currentJob.projectRootPath,
      jobId: currentJob.id,
    );
    final baseJob = (latestJob ?? currentJob).copyWith(
      status: BulkLoopJobStatus.running,
    );
    final mergedJob = _updateContent(baseJob, updatedContent);
    await _repository.save(mergedJob);
    return mergedJob;
  }

  String _buildOutputPath(BulkLoopJob job, BulkLoopContentPlan content) {
    final bgName = content.backgroundVideoPath == null
        ? 'item_${(content.index + 1).toString().padLeft(2, '0')}'
        : p.basenameWithoutExtension(content.backgroundVideoPath!);
    final channelName = _sanitizeFileName(job.name);
    final bgSafeName = _sanitizeFileName(bgName);
    final outputDirectory = _resolveChannelOutputDirectory(
      baseOutputDirectory: job.outputDirectoryPath,
      channelName: channelName,
    );
    final baseName = '$channelName - $bgSafeName';
    return _resolveUniqueOutputPath(outputDirectory, baseName);
  }

  String _sanitizeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? 'untitled' : cleaned;
  }

  String _resolveUniqueOutputPath(String outputDir, String baseName) {
    var candidate = p.join(outputDir, '$baseName.mp4');
    var counter = 2;
    while (FileSystemEntity.typeSync(candidate) !=
        FileSystemEntityType.notFound) {
      candidate = p.join(outputDir, '$baseName ($counter).mp4');
      counter++;
    }
    return candidate;
  }

  String _resolveChannelOutputDirectory({
    required String baseOutputDirectory,
    required String channelName,
  }) {
    final channelOutputDirectory = p.join(baseOutputDirectory, channelName);
    final dir = Directory(channelOutputDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return channelOutputDirectory;
  }
}
