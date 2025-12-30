import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'core/theme/app_theme.dart';
import 'core/services/system_info_service.dart';
import 'features/video_merger/presentation/pages/video_merger_page.dart';

/// Provider to check FFmpeg availability
final ffmpegCheckProvider = FutureProvider<bool>((ref) async {
  return await SystemInfoService.isFFmpegAvailable();
});

class SwalokaApp extends ConsumerWidget {
  const SwalokaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ffmpegCheck = ref.watch(ffmpegCheckProvider);

    return MaterialApp(
      title: 'Swaloka Looping Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: ffmpegCheck.when(
        data: (isAvailable) =>
            isAvailable ? const VideoMergerPage() : const FFmpegErrorPage(),
        loading: () => const _LoadingPage(),
        error: (error, stack) => FFmpegErrorPage(error: error.toString()),
      ),
    );
  }
}

/// Loading page while checking for FFmpeg
class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            const SizedBox(height: 24),
            const Text(
              'Checking FFmpeg installation...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error page shown when FFmpeg is not installed
class FFmpegErrorPage extends StatelessWidget {
  final String? error;

  const FFmpegErrorPage({super.key, this.error});

  String get _installationInstructions {
    if (Platform.isMacOS) {
      return 'Install FFmpeg using Homebrew:\n\n'
          '```bash\n'
          'brew install ffmpeg\n'
          '```\n\n'
          'Or download from: https://evermeet.cx/ffmpeg/';
    } else if (Platform.isLinux) {
      return 'Install FFmpeg using your package manager:\n\n'
          'Ubuntu/Debian:\n'
          '```bash\n'
          'sudo apt update\n'
          'sudo apt install ffmpeg\n'
          '```\n\n'
          'Fedora:\n'
          '```bash\n'
          'sudo dnf install ffmpeg\n'
          '```';
    } else if (Platform.isWindows) {
      return 'Install FFmpeg using one of these methods:\n\n'
          '1. Using Chocolatey:\n'
          '```bash\n'
          'choco install ffmpeg\n'
          '```\n\n'
          '2. Using Scoop:\n'
          '```bash\n'
          'scoop install ffmpeg\n'
          '```\n\n'
          '3. Download from: https://www.gyan.dev/ffmpeg/builds/\n\n'
          'After installation, make sure FFmpeg is added to your System PATH.';
    }
    return 'Please install FFmpeg and add it to your system PATH.';
  }

  Future<void> _openDocumentation() async {
    final url = Uri.parse('https://ffmpeg.org/download.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'FFmpeg Not Found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FFmpeg is required to use this application but it is not installed on your system.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.code,
                              color: Colors.deepPurple,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Installation Instructions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _installationInstructions,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openDocumentation,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open FFmpeg Website'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Attempt to restart the app to re-check
                      // In a real app, you might want to show a dialog
                      // instructing the user to restart the app manually
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text(
                            'Restart Required',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'After installing FFmpeg, please restart this application.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'OK',
                                style: TextStyle(color: Colors.deepPurple),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-check Installation'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: $error',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
