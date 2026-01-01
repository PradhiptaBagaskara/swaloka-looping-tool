import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import '../providers/ffmpeg_provider.dart';

/// Error page shown when FFmpeg is not installed
class FFmpegErrorPage extends ConsumerWidget {
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

  static Widget _buildTroubleshootingStep(
    String number,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                            Icon(Icons.code, color: Colors.deepPurple, size: 20),
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
                    onPressed: () async {
                      // Show checking dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const AlertDialog(
                          backgroundColor: Color(0xFF1E1E1E),
                          content: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.deepPurple,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Text(
                                  'Checking FFmpeg...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      // Wait a moment for the dialog to show
                      await Future.delayed(const Duration(milliseconds: 300));

                      // Perform the actual check (reset cache first)
                      FFmpegService.resetCache();
                      final isAvailable = await FFmpegService.isAvailable();

                      // Close the checking dialog
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }

                      if (!isAvailable && context.mounted) {
                        // Still not found, show helpful troubleshooting dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'FFmpeg Still Not Found',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FFmpeg is still not detected. Please try the following:',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTroubleshootingStep(
                                    '1',
                                    'Verify FFmpeg is installed',
                                    'Open your terminal and run:\nffmpeg -version',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTroubleshootingStep(
                                    '2',
                                    'Check System PATH',
                                    'Make sure FFmpeg is added to your system PATH environment variable.',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTroubleshootingStep(
                                    '3',
                                    'Restart Terminal/Shell',
                                    'If you just installed FFmpeg, restart your terminal or shell session.',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTroubleshootingStep(
                                    '4',
                                    'Restart This App',
                                    'If the above steps don\'t work, try restarting this application.',
                                  ),
                                ],
                              ),
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
                      } else if (isAvailable && context.mounted) {
                        // FFmpeg found! Update status and navigate back
                        ref.read(ffmpegStatusProvider.notifier).setStatus(true);
                        Navigator.of(context).pop(); // Go back to landing page
                      }
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
