import 'package:swaloka_looping_tool/core/services/log_service.dart';

/// State for video processing operations
class ProcessingState {
  final bool isProcessing;
  final double progress;
  final List<LogEntry> logs;
  final String? error;
  final String? outputPath;
  final DateTime? startTime;
  final Map<String, int>
  outputLoopCounts; // Track loop count for each output file

  ProcessingState({
    required this.isProcessing,
    required this.progress,
    required this.logs,
    this.error,
    this.outputPath,
    this.startTime,
    this.outputLoopCounts = const {},
  });

  factory ProcessingState.idle() => ProcessingState(
    isProcessing: false,
    progress: 0.0,
    logs: [],
    outputLoopCounts: const {},
  );

  ProcessingState copyWith({
    bool? isProcessing,
    double? progress,
    List<LogEntry>? logs,
    String? error,
    String? outputPath,
    DateTime? startTime,
  }) {
    return ProcessingState(
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      error: error ?? this.error,
      outputPath: outputPath ?? this.outputPath,
      startTime: startTime ?? this.startTime,
    );
  }
}
