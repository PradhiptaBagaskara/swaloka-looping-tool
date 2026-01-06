import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';

/// Notifier for managing the active project (persisted settings only)
/// Session-only data (file selections, metadata) are managed in UI state
class ActiveProjectNotifier extends Notifier<SwalokaProject?> {
  static const _lastProjectPathKey = 'last_project_path';
  static const _projectSettingFileName = 'project.swaloka';

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
    void Function(String path)? onProjectAdded,
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
    void Function(String path)? onProjectAdded,
    VoidCallback? onFilesRefresh,
  }) async {
    // Normalize the rootPath for the current platform
    final normalizedRootPath = p.normalize(rootPath);

    final file = File(p.join(normalizedRootPath, _projectSettingFileName));
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      final loadedProject = SwalokaProject.fromJson(
        json as Map<String, dynamic>,
      );

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
    int? concurrencyLimit,
    IntroAudioMode? introAudioMode,
  }) async {
    if (state == null) return;
    final newState = state!.copyWith(
      customOutputPath: customOutputPath,
      clearCustomOutputPath: clearCustomOutputPath,
      concurrencyLimit: concurrencyLimit,
      introAudioMode: introAudioMode,
    );
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> _saveProjectToFile(SwalokaProject project) async {
    final file = File(p.join(project.rootPath, _projectSettingFileName));
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
    } on Exception catch (_) {
      // Ignore cleanup errors
    }
  }

  Future<void> closeProject() async {
    // Cleanup temp directories before closing
    if (state != null) {
      await _cleanupTempDirectories(state!.rootPath);
    }
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastProjectPathKey);
  }
}
