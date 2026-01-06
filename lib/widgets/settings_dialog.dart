import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/theme/theme.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/ffmpeg_provider.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/settings_notifier.dart';

/// Dialog for app settings
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _ffmpegController = TextEditingController();
  bool _isValidating = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final settings = ref.read(settingsProvider);
    settings.whenData((value) {
      _ffmpegController.text = value.customFfmpegPath ?? '';
    });
  }

  @override
  void dispose() {
    _ffmpegController.dispose();
    super.dispose();
  }

  Future<void> _browseFfmpeg() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select FFmpeg executable',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _ffmpegController.text = result.files.single.path!;
        _validationError = null;
      });
    }
  }

  Future<void> _validateAndSave() async {
    final path = _ffmpegController.text.trim();

    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      if (path.isNotEmpty) {
        // Validate the path
        final isValid = await FFmpegService.validatePath(path);
        if (!isValid) {
          setState(() {
            _validationError =
                'Invalid FFmpeg path. Make sure it exists and is executable.';
            _isValidating = false;
          });
          return;
        }
      }

      // Save the path (empty = auto-detect)
      await ref
          .read(settingsProvider.notifier)
          .setFfmpegPath(path.isEmpty ? null : path);

      // Trigger FFmpeg re-check
      await ref.read(ffmpegStatusProvider.notifier).recheckFFmpeg();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      setState(() {
        _validationError = 'Failed to save: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  void _resetToDefault() {
    setState(() {
      _ffmpegController.clear();
      _validationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Settings'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            Text(
              'Appearance',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose between light and dark theme.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, child) {
                final themeMode = ref.watch(themeModeProvider);
                final isDark = themeMode == ThemeMode.dark;

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      isDark ? 'Dark Theme' : 'Light Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      isDark
                          ? 'Darker interface for low-light environments'
                          : 'Brighter interface for well-lit environments',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: isDark,
                    onChanged: (_) {
                      ref.read(themeModeProvider.notifier).toggleTheme();
                    },
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // FFmpeg Path Section
            Text(
              'FFmpeg Path',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'By default, FFmpeg is auto-detected from system PATH. '
              'You can set a custom path if needed.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Current detected path
            settings.when(
              data: (value) => _buildCurrentPathInfo(value, ffmpegStatus),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),

            // Path input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ffmpegController,
                    decoration: InputDecoration(
                      hintText: 'Auto-detect (leave empty)',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      errorText: _validationError,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setState(() {
                      _validationError = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _browseFfmpeg,
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Browse...',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reset button
            if (_ffmpegController.text.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _resetToDefault,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset to auto-detect'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _validateAndSave,
          child: _isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCurrentPathInfo(SettingsState settings, bool? ffmpegStatus) {
    final isAvailable = ffmpegStatus ?? false;
    final currentPath = FFmpegService.ffmpegPath;
    final isCustom = settings.hasCustomFfmpegPath;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAvailable
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.warning,
            size: 20,
            color: isAvailable ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? 'FFmpeg detected' : 'FFmpeg not found',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isAvailable ? Colors.green[300] : Colors.orange[300],
                  ),
                ),
                if (isAvailable)
                  Text(
                    currentPath,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (isCustom)
                  Text(
                    '(Custom path)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show settings dialog
Future<bool?> showSettingsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}
