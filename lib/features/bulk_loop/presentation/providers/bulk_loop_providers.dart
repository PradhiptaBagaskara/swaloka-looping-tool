import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/data/bulk_loop_job_repository.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/bulk_loop_executor_service.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/bulk_loop_planner_service.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';

final bulkLoopJobRepositoryProvider = Provider<BulkLoopJobRepository>(
  (ref) => BulkLoopJobRepository(),
);

final bulkLoopPlannerServiceProvider = Provider<BulkLoopPlannerService>(
  (ref) => BulkLoopPlannerService(),
);

final bulkLoopExecutorServiceProvider = Provider<BulkLoopExecutorService>(
  (ref) => BulkLoopExecutorService(
    repository: ref.watch(bulkLoopJobRepositoryProvider),
    mergerService: ref.watch(videoMergerServiceProvider),
  ),
);
