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
      state = loadedProject.copyWith(rootPath: normalizedRootPath);

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
