import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/swaloka_project.dart';

/// Notifier for managing the active project
class ActiveProjectNotifier extends Notifier<SwalokaProject?> {
  static const _lastProjectPathKey = 'last_project_path';

  @override
  SwalokaProject? build() {
    _loadLastProject();
    return null;
  }

  Future<void> _loadLastProject() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_lastProjectPathKey);
    if (path != null) {
      await loadProject(path);
    }
  }

  Future<void> createProject(
    String rootPath,
    String name, {
    Function(String path)? onProjectAdded,
    VoidCallback? onFilesRefresh,
  }) async {
    // Normalize the rootPath for the current platform
    final normalizedRootPath = p.normalize(rootPath);

    final project = SwalokaProject(name: name, rootPath: normalizedRootPath);
    await _saveProjectToFile(project);

    // Ensure directories
    await Directory(
      p.join(normalizedRootPath, 'outputs'),
    ).create(recursive: true);
    await Directory(p.join(normalizedRootPath, 'logs')).create(recursive: true);
    await Directory(p.join(normalizedRootPath, 'temp')).create(recursive: true);

    state = project;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastProjectPathKey, normalizedRootPath);

    // Notify callbacks
    onProjectAdded?.call(normalizedRootPath);
    onFilesRefresh?.call();
  }

  Future<void> loadProject(
    String rootPath, {
    Function(String path)? onProjectAdded,
    VoidCallback? onFilesRefresh,
  }) async {
    // Normalize the rootPath for the current platform
    final normalizedRootPath = p.normalize(rootPath);

    final file = File(p.join(normalizedRootPath, 'project.swaloka'));
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      final loadedProject = SwalokaProject.fromJson(json);

      // Use the rootPath parameter (from Recent Projects) instead of the one from JSON
      // This ensures we use the correct path even if the JSON has a stale/incorrect path
      var updatedProject = loadedProject.copyWith(rootPath: normalizedRootPath);

      // Validate and fix audio/video file paths if they don't exist
      // This handles cases where the project was moved or paths became invalid
      updatedProject = await _validateAndFixFilePaths(
        updatedProject,
        loadedProject.rootPath,
        normalizedRootPath,
      );

      state = updatedProject;

      // Ensure directories exist (in case they were deleted)
      await Directory(
        p.join(normalizedRootPath, 'outputs'),
      ).create(recursive: true);
      await Directory(
        p.join(normalizedRootPath, 'logs'),
      ).create(recursive: true);
      await Directory(
        p.join(normalizedRootPath, 'temp'),
      ).create(recursive: true);

      // Clean up old temp directories from previous sessions
      await _cleanupTempDirectories(normalizedRootPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastProjectPathKey, normalizedRootPath);

      // Notify callbacks
      onProjectAdded?.call(normalizedRootPath);
      onFilesRefresh?.call();
    }
  }

  /// Validate and fix file paths if they don't exist
  /// Attempts to find files relative to the new root path if old paths are invalid
  Future<SwalokaProject> _validateAndFixFilePaths(
    SwalokaProject project,
    String oldRootPath,
    String newRootPath,
  ) async {
    // Skip validation if paths haven't changed
    if (oldRootPath == newRootPath) {
      return project;
    }

    // Helper to fix a single path
    Future<String?> fixPath(String? filePath) async {
      if (filePath == null) return null;

      // If file exists at current path, no fix needed
      if (await File(filePath).exists()) {
        return filePath;
      }

      // Try to find the file relative to new root path
      // Extract just the filename
      final fileName = p.basename(filePath);

      // Check common locations in the new root path
      final possiblePaths = [
        p.join(newRootPath, fileName),
        p.join(newRootPath, 'audio', fileName),
        p.join(newRootPath, 'video', fileName),
        p.join(newRootPath, 'media', fileName),
      ];

      for (final possiblePath in possiblePaths) {
        if (await File(possiblePath).exists()) {
          return possiblePath;
        }
      }

      // If not found, return null (file is missing)
      return null;
    }

    // Fix background video path
    final fixedBackgroundVideo = await fixPath(project.backgroundVideo);

    // Fix audio file paths
    final fixedAudioFiles = <String>[];
    for (final audioPath in project.audioFiles) {
      final fixed = await fixPath(audioPath);
      if (fixed != null) {
        fixedAudioFiles.add(fixed);
      }
      // Skip files that couldn't be found
    }

    // Return updated project only if changes were made
    if (fixedBackgroundVideo != project.backgroundVideo ||
        fixedAudioFiles.length != project.audioFiles.length) {
      final updatedProject = project.copyWith(
        backgroundVideo: fixedBackgroundVideo,
        audioFiles: fixedAudioFiles,
        clearBackgroundVideo: fixedBackgroundVideo == null,
      );

      // Save the fixed paths back to the project file
      await _saveProjectToFile(updatedProject);

      return updatedProject;
    }

    return project;
  }

  Future<void> updateSettings({
    String? customOutputPath,
    bool clearCustomOutputPath = false,
    String? title,
    String? author,
    String? comment,
    int? concurrencyLimit,
    int? audioLoopCount,
  }) async {
    if (state == null) return;
    final newState = state!.copyWith(
      customOutputPath: customOutputPath,
      clearCustomOutputPath: clearCustomOutputPath,
      title: title,
      author: author,
      comment: comment,
      concurrencyLimit: concurrencyLimit,
      audioLoopCount: audioLoopCount,
    );
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> setBackgroundVideo(String? path) async {
    if (state == null) return;
    final newState = state!.copyWith(
      backgroundVideo: path,
      clearBackgroundVideo: path == null,
    );
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> setAudioFiles(List<String> files) async {
    if (state == null) return;
    final newState = state!.copyWith(audioFiles: files);
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> removeAudioAt(int index) async {
    if (state == null) return;
    final newList = List<String>.from(state!.audioFiles);
    newList.removeAt(index);
    final newState = state!.copyWith(audioFiles: newList);
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> removeAllAudios() async {
    if (state == null) return;
    final newState = state!.copyWith(audioFiles: []);
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> _saveProjectToFile(SwalokaProject project) async {
    final file = File(p.join(project.rootPath, 'project.swaloka'));
    await file.writeAsString(jsonEncode(project.toJson()));
  }

  /// Clean up old temp directories in the project
  Future<void> _cleanupTempDirectories(String rootPath) async {
    try {
      final tempDir = Directory(p.join(rootPath, 'temp'));
      if (await tempDir.exists()) {
        final contents = tempDir.listSync();
        for (final item in contents) {
          if (item is Directory) {
            // Delete old temp directories
            await item.delete(recursive: true);
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  void closeProject() async {
    // Cleanup temp directories before closing
    if (state != null) {
      await _cleanupTempDirectories(state!.rootPath);
    }
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastProjectPathKey);
  }
}
