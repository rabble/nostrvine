// ABOUTME: Widget for displaying video upload progress with status indicators
// ABOUTME: Shows upload progress, processing state, and error handling UI

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/pending_upload.dart';

/// Widget that displays upload progress for a video
class UploadProgressIndicator extends StatelessWidget {
  const UploadProgressIndicator({
    required this.upload,
    super.key,
    this.onRetry,
    this.onCancel,
    this.onDelete,
    this.onPause,
    this.onResume,
    this.onTap,
    this.showActions = true,
  });
  final PendingUpload upload;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upload.title ?? context.l10n.uploadProgressVideoUpload,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        upload.statusText,
                        style: TextStyle(
                          color: _getStatusColor(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(),
              ],
            ),
            const SizedBox(height: 8),
            _buildProgressBar(context),
            if (showActions &&
                (upload.canRetry ||
                    upload.status == UploadStatus.uploading ||
                    upload.status == UploadStatus.paused ||
                    upload.status == UploadStatus.failed))
              const SizedBox(height: 8),
            if (showActions &&
                (upload.canRetry ||
                    upload.status == UploadStatus.uploading ||
                    upload.status == UploadStatus.paused ||
                    upload.status == UploadStatus.failed))
              _buildActionButtons(context),
          ],
        ),
      ),
    ),
  );

  Widget _buildStatusIcon() {
    switch (upload.status) {
      case UploadStatus.pending:
        return const Icon(Icons.schedule, color: VineTheme.warning);
      case UploadStatus.uploading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UploadStatus.retrying:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VineTheme.warning,
          ),
        );
      case UploadStatus.processing:
        return const Icon(Icons.settings, color: VineTheme.info);
      case UploadStatus.readyToPublish:
        return const Icon(Icons.publish, color: VineTheme.vineGreen);
      case UploadStatus.published:
        return const Icon(Icons.check_circle, color: VineTheme.vineGreen);
      case UploadStatus.failed:
        return const Icon(Icons.error, color: VineTheme.error);
      case UploadStatus.paused:
        return const Icon(Icons.pause_circle, color: VineTheme.warning);
    }
  }

  Widget _buildProgressBar(BuildContext context) {
    final progress = upload.progressValue;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: VineTheme.secondaryText,
          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: VineTheme.lightText),
            ),
            Text(
              _getTimeInfo(context),
              style: const TextStyle(fontSize: 12, color: VineTheme.lightText),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (upload.status == UploadStatus.uploading && onPause != null)
        ElevatedButton.icon(
          onPressed: onPause,
          icon: const Icon(Icons.pause),
          label: Text(context.l10n.uploadProgressPause),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.info,
            foregroundColor: VineTheme.whiteText,
          ),
        ),
      if (upload.status == UploadStatus.paused && onResume != null)
        ElevatedButton.icon(
          onPressed: onResume,
          icon: const Icon(Icons.play_arrow),
          label: Text(context.l10n.uploadProgressResume),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.warning,
            foregroundColor: VineTheme.whiteText,
          ),
        ),
      if (upload.status == UploadStatus.failed) ...[
        if (onCancel != null) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.cardBackground,
              foregroundColor: VineTheme.whiteText,
            ),
            child: Text(context.l10n.uploadProgressGoBack),
          ),
        ],
        if (onRetry != null && upload.canRetry) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.warning,
              foregroundColor: VineTheme.whiteText,
            ),
            child: Text(
              context.l10n.uploadProgressRetryWithCount(
                3 - (upload.retryCount ?? 0),
              ),
            ),
          ),
        ],
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: VineTheme.error),
            child: Text(context.l10n.uploadProgressDelete),
          ),
        ],
      ] else if (upload.canRetry && onRetry != null) ...[
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.warning,
            foregroundColor: VineTheme.whiteText,
          ),
          child: Text(
            context.l10n.uploadProgressRetryWithCount(
              3 - (upload.retryCount ?? 0),
            ),
          ),
        ),
      ],
    ],
  );

  Color _getStatusColor(BuildContext context) {
    switch (upload.status) {
      case UploadStatus.pending:
        return VineTheme.warning;
      case UploadStatus.uploading:
        return VineTheme.info;
      case UploadStatus.retrying:
        return VineTheme.warning;
      case UploadStatus.processing:
        return VineTheme.info;
      case UploadStatus.readyToPublish:
        return VineTheme.vineGreen;
      case UploadStatus.published:
        return VineTheme.vineGreen;
      case UploadStatus.failed:
        return VineTheme.error;
      case UploadStatus.paused:
        return VineTheme.warning;
    }
  }

  Color _getProgressColor() {
    switch (upload.status) {
      case UploadStatus.pending:
        return VineTheme.warning;
      case UploadStatus.uploading:
        return VineTheme.info;
      case UploadStatus.retrying:
        return VineTheme.warning;
      case UploadStatus.processing:
        return VineTheme.info;
      case UploadStatus.readyToPublish:
        return VineTheme.vineGreen;
      case UploadStatus.published:
        return VineTheme.vineGreen;
      case UploadStatus.failed:
        return VineTheme.error;
      case UploadStatus.paused:
        return VineTheme.warning;
    }
  }

  String _getTimeInfo(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(upload.createdAt);

    if (diff.inDays > 0) {
      return context.l10n.uploadProgressDaysAgo(diff.inDays);
    } else if (diff.inHours > 0) {
      return context.l10n.uploadProgressHoursAgo(diff.inHours);
    } else if (diff.inMinutes > 0) {
      return context.l10n.uploadProgressMinutesAgo(diff.inMinutes);
    } else {
      return context.l10n.uploadProgressJustNow;
    }
  }
}

/// Compact version of upload progress for notifications
class CompactUploadProgress extends StatelessWidget {
  const CompactUploadProgress({required this.upload, super.key, this.onTap});
  final PendingUpload upload;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: upload.progressValue,
              strokeWidth: 2,
              backgroundColor: VineTheme.lightText,
              valueColor: AlwaysStoppedAnimation<Color>(
                upload.status == UploadStatus.failed
                    ? VineTheme.error
                    : VineTheme.whiteText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            upload.status == UploadStatus.uploading
                ? context.l10n.uploadProgressUploadingPercent(
                    (upload.progressValue * 100).toInt(),
                  )
                : upload.status == UploadStatus.paused
                ? context.l10n.uploadProgressPausedPercent(
                    (upload.progressValue * 100).toInt(),
                  )
                : upload.statusText,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
