import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/features/media_tools/domain/media_tools_service.dart';

final mediaToolsServiceProvider = Provider<MediaToolsService>((ref) {
  return MediaToolsService();
});
