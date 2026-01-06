import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for managing collapsed/expanded sections in UI
class CollapsedSectionsNotifier extends Notifier<Set<String>> {
  static const Set<String> _defaultCollapsed = {
    'Advanced Looper Settings',
    'Video Tags Metadata (Optional)',
    // 'Intro Video (Optional)' - now expanded by default for better UX
  };

  @override
  Set<String> build() => _defaultCollapsed;

  void toggle(String title) {
    final newState = Set<String>.from(state);
    if (newState.contains(title)) {
      newState.remove(title); // Expand section
    } else {
      newState.add(title); // Collapse section
    }
    state = newState;
  }

  void collapseAll(Iterable<String> titles) {
    state = {...titles};
  }

  void expandAll() {
    state = {};
  }
}
