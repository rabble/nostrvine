// ABOUTME: Widget for displaying video upload and processing status with appropriate UI indicators
// ABOUTME: Shows progress bars, processing states, success/error indicators based on upload status

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:unified_logger/unified_logger.dart';

/// Widget that displays the current status of a video upload/processing operation
class VideoProcessingStatusWidget extends ConsumerWidget {
  final String uploadId;

  const VideoProcessingStatusWidget({required this.uploadId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadManager = ref.watch(uploadManagerProvider);
    final upload = uploadManager.getUpload(uploadId);

    if (upload == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusHeader(upload),
            const SizedBox(height: 12),
            _buildProgressIndicator(upload),
            const SizedBox(height: 8),
            _buildStatusMessage(upload),
            if (upload.status == UploadStatus.failed) ...[
              const SizedBox(height: 12),
              _buildRetryButton(context, ref),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(PendingUpload upload) {
    IconData icon;
    Color color;
    String title;

    switch (upload.status) {
      case UploadStatus.pending:
        icon = Icons.schedule;
        color = VineTheme.warning;
        title = 'Waiting to upload';
      case UploadStatus.uploading:
        icon = Icons.cloud_upload;
        color = VineTheme.vineGreen;
        title = 'Uploading video';
      case UploadStatus.processing:
        icon = Icons.hourglass_empty;
        color = VineTheme.info;
        title = 'Processing video';
      case UploadStatus.readyToPublish:
        icon = Icons.check_circle;
        color = VineTheme.success;
        title = 'Processing complete';
      case UploadStatus.published:
        icon = Icons.check_circle;
        color = VineTheme.success;
        title = 'Published successfully';
      case UploadStatus.failed:
        icon = Icons.error;
        color = VineTheme.error;
        title = 'Upload failed';
      case UploadStatus.retrying:
        icon = Icons.refresh;
        color = VineTheme.warning;
        title = 'Retrying upload';
      case UploadStatus.paused:
        icon = Icons.pause;
        color = VineTheme.lightText;
        title = 'Upload paused';
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (upload.status == UploadStatus.processing) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressIndicator(PendingUpload upload) {
    final progress = upload.uploadProgress ?? 0.0;

    if (upload.status == UploadStatus.failed ||
        upload.status == UploadStatus.published) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: VineTheme.secondaryText,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(upload.status),
          ),
          minHeight: 4,
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% complete',
          style: const TextStyle(fontSize: 12, color: VineTheme.lightText),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(PendingUpload upload) {
    String message;
    Color? textColor;

    switch (upload.status) {
      case UploadStatus.pending:
        message = 'Your video is queued for upload';
      case UploadStatus.uploading:
        message = 'Uploading to server...';
      case UploadStatus.processing:
        message = 'Processing video - this may take a few minutes';
        textColor = VineTheme.info;
      case UploadStatus.readyToPublish:
        message = 'Video processed successfully and ready to publish';
        textColor = VineTheme.success;
      case UploadStatus.published:
        message = 'Video published to your profile';
        textColor = VineTheme.success;
      case UploadStatus.failed:
        message = upload.errorMessage ?? 'Upload failed - please try again';
        textColor = VineTheme.error;
      case UploadStatus.retrying:
        message = 'Retrying upload...';
      case UploadStatus.paused:
        message = 'Upload paused by user';
    }

    return Text(
      message,
      style: TextStyle(
        fontSize: 14,
        color: textColor ?? VineTheme.secondaryText,
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          try {
            final uploadManager = ref.read(uploadManagerProvider);
            await uploadManager.retryUpload(uploadId);

            Log.info(
              'Retrying upload: $uploadId',
              name: 'VideoProcessingStatusWidget',
              category: LogCategory.ui,
            );
          } catch (e) {
            Log.error(
              'Failed to retry upload: $e',
              name: 'VideoProcessingStatusWidget',
              category: LogCategory.ui,
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to retry upload: $e'),
                  backgroundColor: VineTheme.error,
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.whiteText,
        ),
        child: const Text('RETRY'),
      ),
    );
  }

  Color _getProgressColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.uploading:
        return VineTheme.vineGreen;
      case UploadStatus.processing:
        return VineTheme.info;
      case UploadStatus.readyToPublish:
      case UploadStatus.published:
        return VineTheme.success;
      case UploadStatus.retrying:
        return VineTheme.warning;
      default:
        return VineTheme.lightText;
    }
  }
}
