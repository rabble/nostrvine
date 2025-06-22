// ABOUTME: Example integration code for pause/resume upload functionality
// ABOUTME: Shows how to wire up the new pause/resume methods with the UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/upload_manager.dart';
import '../widgets/upload_progress_indicator.dart';

/// Example screen showing how to integrate pause/resume functionality
class PauseResumeExample extends StatelessWidget {
  const PauseResumeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Progress'),
      ),
      body: Consumer<UploadManager>(
        builder: (context, uploadManager, child) {
          final uploads = uploadManager.pendingUploads;
          
          if (uploads.isEmpty) {
            return const Center(
              child: Text('No uploads in progress'),
            );
          }
          
          return ListView.builder(
            itemCount: uploads.length,
            itemBuilder: (context, index) {
              final upload = uploads[index];
              
              return UploadProgressIndicator(
                upload: upload,
                onPause: () {
                  // Call the new pauseUpload method
                  uploadManager.pauseUpload(upload.id);
                },
                onResume: () {
                  // Call the new resumeUpload method
                  uploadManager.resumeUpload(upload.id);
                },
                onRetry: () {
                  uploadManager.retryUpload(upload.id);
                },
                onDelete: () {
                  uploadManager.deleteUpload(upload.id);
                },
                onTap: () {
                  // Optional: Show upload details
                  _showUploadDetails(context, upload);
                },
              );
            },
          );
        },
      ),
    );
  }
  
  void _showUploadDetails(BuildContext context, upload) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(upload.title ?? 'Upload Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${upload.statusText}'),
            Text('Progress: ${(upload.progressValue * 100).toInt()}%'),
            if (upload.errorMessage != null)
              Text('Error: ${upload.errorMessage}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Example of how to integrate in existing screens
/// 
/// In your existing upload screen (e.g., camera_screen.dart), update the
/// UploadProgressIndicator usage like this:
/// 
/// ```dart
/// UploadProgressIndicator(
///   upload: upload,
///   onPause: () => uploadManager.pauseUpload(upload.id),
///   onResume: () => uploadManager.resumeUpload(upload.id),
///   onRetry: () => uploadManager.retryUpload(upload.id),
///   onDelete: () => uploadManager.deleteUpload(upload.id),
/// )
/// ```
/// 
/// The pause button will automatically appear during active uploads,
/// and the resume button will appear for paused uploads.