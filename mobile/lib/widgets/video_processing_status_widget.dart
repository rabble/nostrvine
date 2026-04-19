// ABOUTME: Widget for displaying video upload and processing status with appropriate UI indicators
// ABOUTME: Shows progress bars, processing states, success/error indicators based on upload status

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
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
            _buildStatusHeader(context, upload),
            const SizedBox(height: 12),
            _buildProgressIndicator(context, upload),
            const SizedBox(height: 8),
            _buildStatusMessage(context, upload),
            if (upload.status == UploadStatus.failed) ...[
              const SizedBox(height: 12),
              _buildRetryButton(context, ref),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, PendingUpload upload) {
    IconData icon;
    Color color;
    String title;
    final l10n = context.l10n;

    switch (upload.status) {
      case UploadStatus.pending:
        icon = Icons.schedule;
        color = VineTheme.warning;
        title = l10n.uploadWaitingToUpload;
      case UploadStatus.uploading:
        icon = Icons.cloud_upload;
        color = VineTheme.vineGreen;
        title = l10n.uploadUploadingVideo;
      case UploadStatus.processing:
        icon = Icons.hourglass_empty;
        color = VineTheme.info;
        title = l10n.uploadProcessingVideo;
      case UploadStatus.readyToPublish:
        icon = Icons.check_circle;
        color = VineTheme.success;
        title = l10n.uploadProcessingComplete;
      case UploadStatus.published:
        icon = Icons.check_circle;
        color = VineTheme.success;
        title = l10n.uploadPublishedSuccessfully;
      case UploadStatus.failed:
        icon = Icons.error;
        color = VineTheme.error;
        title = l10n.uploadFailed;
      case UploadStatus.retrying:
        icon = Icons.refresh;
        color = VineTheme.warning;
        title = l10n.uploadRetrying;
      case UploadStatus.paused:
        icon = Icons.pause;
        color = VineTheme.lightText;
        title = l10n.uploadPaused;
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

  Widget _buildProgressIndicator(BuildContext context, PendingUpload upload) {
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
          context.l10n.uploadPercentComplete((progress * 100).toInt()),
          style: const TextStyle(fontSize: 12, color: VineTheme.lightText),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(BuildContext context, PendingUpload upload) {
    String message;
    Color? textColor;
    final l10n = context.l10n;

    switch (upload.status) {
      case UploadStatus.pending:
        message = l10n.uploadQueuedMessage;
      case UploadStatus.uploading:
        message = l10n.uploadUploadingMessage;
      case UploadStatus.processing:
        message = l10n.uploadProcessingMessage;
        textColor = VineTheme.info;
      case UploadStatus.readyToPublish:
        message = l10n.uploadReadyToPublishMessage;
        textColor = VineTheme.success;
      case UploadStatus.published:
        message = l10n.uploadPublishedMessage;
        textColor = VineTheme.success;
      case UploadStatus.failed:
        message = upload.errorMessage ?? l10n.uploadFailedMessage;
        textColor = VineTheme.error;
      case UploadStatus.retrying:
        message = l10n.uploadRetryingMessage;
      case UploadStatus.paused:
        message = l10n.uploadPausedMessage;
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
                  content: Text(context.l10n.uploadRetryFailed('$e')),
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
        child: Text(context.l10n.uploadRetryButton),
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
