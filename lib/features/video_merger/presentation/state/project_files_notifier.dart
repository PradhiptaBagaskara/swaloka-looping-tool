import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for managing project output files
class ProjectFilesNotifier extends Notifier<List<FileSystemEntity>> {
  @override
  List<FileSystemEntity> build() => [];

  void refresh(String? effectiveOutputPath) {
    if (effectiveOutputPath == null) {
      state = [];
      return;
    }

    final outputsDir = Directory(effectiveOutputPath);
    if (outputsDir.existsSync()) {
      state =
          outputsDir
              .listSync()
              .where((file) => file.path.endsWith('.mp4'))
              .toList()
            ..sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
            );
    } else {
      state = [];
    }
  }
}
