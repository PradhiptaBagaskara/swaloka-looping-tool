import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'processing_state.dart';

/// Notifier for managing processing state
class ProcessingStateNotifier extends Notifier<ProcessingState> {
  @override
  ProcessingState build() => ProcessingState.idle();

  void startProcessing() {
    state = ProcessingState(
      isProcessing: true,
      progress: 0.0,
      logs: [],
      startTime: DateTime.now(),
    );
  }

  void updateProgress(double progress) =>
      state = state.copyWith(isProcessing: true, progress: progress);

  void addLog(LogEntry log) {
    state = state.copyWith(isProcessing: true, logs: [...state.logs, log]);
  }

  void setSuccess(String outputPath) => state = ProcessingState(
    isProcessing: false,
    progress: 1.0,
    outputPath: outputPath,
    logs: state.logs,
    startTime: state.startTime,
  );

  void setError(String error) => state = ProcessingState(
    isProcessing: false,
    progress: 0.0,
    error: error,
    logs: [...state.logs, LogEntry.error('ERROR: $error')],
    startTime: state.startTime,
  );

  void reset() => state = ProcessingState.idle();
}
