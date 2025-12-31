import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier for managing recent projects list
class RecentProjectsNotifier extends Notifier<List<String>> {
  static const _recentProjectsKey = 'recent_projects';

  @override
  List<String> build() {
    _loadRecentProjects();
    return [];
  }

  Future<void> _loadRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentProjectsKey) ?? [];
    state = list;
  }

  Future<void> addProject(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(state);
    current.remove(path); // Remove if exists to move to top
    current.insert(0, path);
    if (current.length > 5) current.removeLast(); // Keep last 5

    state = current;
    await prefs.setStringList(_recentProjectsKey, current);
  }

  Future<void> removeProject(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(state);
    current.remove(path);
    state = current;
    await prefs.setStringList(_recentProjectsKey, current);
  }
}
