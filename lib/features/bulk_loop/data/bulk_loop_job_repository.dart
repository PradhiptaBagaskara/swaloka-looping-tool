import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/features/bulk_loop/domain/models/models.dart';

class BulkLoopJobRepository {
  static const _bulkJobDirectoryName = 'bulk_jobs';

  String _bulkJobDirectoryPath(String projectRootPath) {
    return p.join(projectRootPath, _bulkJobDirectoryName);
  }

  String _jobFilePath(String projectRootPath, String jobId) {
    return p.join(_bulkJobDirectoryPath(projectRootPath), '$jobId.json');
  }

  Future<void> save(BulkLoopJob job) async {
    final dir = Directory(_bulkJobDirectoryPath(job.projectRootPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(_jobFilePath(job.projectRootPath, job.id));
    final content = const JsonEncoder.withIndent('  ').convert(job.toJson());
    await file.writeAsString(content);
  }

  Future<BulkLoopJob?> load({
    required String projectRootPath,
    required String jobId,
  }) async {
    final file = File(_jobFilePath(projectRootPath, jobId));
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final jsonMap = jsonDecode(content) as Map<String, dynamic>;
    return BulkLoopJob.fromJson(jsonMap);
  }

  Future<List<BulkLoopJob>> list(String projectRootPath) async {
    final dir = Directory(_bulkJobDirectoryPath(projectRootPath));
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final jobs = <BulkLoopJob>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;
        jobs.add(BulkLoopJob.fromJson(jsonMap));
      } on Exception {
        // Skip malformed job file.
      }
    }

    jobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return jobs;
  }

  Future<void> delete({
    required String projectRootPath,
    required String jobId,
  }) async {
    final file = File(_jobFilePath(projectRootPath, jobId));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
