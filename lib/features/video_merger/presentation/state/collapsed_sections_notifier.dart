import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for managing collapsed/expanded sections in UI
class CollapsedSectionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'ADVANCED ENCODING SETTINGS'};

  void toggle(String title) {
    if (state.contains(title)) {
      state = state.where((t) => t != title).toSet();
    } else {
      state = {...state, title};
    }
  }
}
