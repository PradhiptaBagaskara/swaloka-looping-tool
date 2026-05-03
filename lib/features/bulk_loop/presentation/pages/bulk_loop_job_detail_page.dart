import 'package:flutter/material.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/presentation/pages/bulk_loop_page.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';

class BulkLoopJobDetailPage extends StatelessWidget {
  const BulkLoopJobDetailPage({
    required this.project,
    required this.jobId,
    super.key,
  });

  final SwalokaProject project;
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Looping Gradakan'),
      ),
      body: BulkLoopPage(
        project: project,
        initialJobId: jobId,
      ),
    );
  }
}
