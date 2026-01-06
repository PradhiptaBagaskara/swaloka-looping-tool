import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for managing collapsed/expanded sections in UI
class CollapsedSectionsNotifier extends Notifier<Set<String>> {
  static const Set<String> _defaultCollapsed = {
    'Advanced Looper Settings',
    'Video Tags Metadata (Optional)',
    'Intro Video (Optional)',
  };

  @override
  Set<String> build() => _defaultCollapsed;

  void toggle(String title) {
    if (state.contains(title)) {
      state = state.where((t) => t != title).toSet();
    } else {
      state = {...state, title};
    }
  }

  void collapseAll(Iterable<String> titles) {
    state = {...titles};
  }

  void expandAll() {
    state = {};
  }
}
