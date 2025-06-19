// ABOUTME: Widget for displaying individual upload items in the upload manager
// ABOUTME: Shows upload progress, status, metadata, and action buttons for each upload

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/pending_upload.dart';

class UploadListItem extends StatelessWidget {
  final PendingUpload upload;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool showThumbnail;
  final bool showProgress;

  const UploadListItem({
    super.key,
    required this.upload,
    this.onRetry,
    this.onCancel,
    this.onDelete,
    this.onTap,
    this.showThumbnail = true,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey[900],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Video thumbnail (conditionally shown)
              if (showThumbnail) ...[
                _buildThumbnail(),
                const SizedBox(width: 12),
              ],
              
              // Upload info and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleAndMetadata(),
                    const SizedBox(height: 8),
                    _buildStatusAndProgress(),
                    if (upload.errorMessage != null) ...[
                      const SizedBox(height: 4),
                      _buildErrorMessage(),
                    ],
                  ],
                ),
              ),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: upload.thumbnailPath != null && File(upload.thumbnailPath!).existsSync()
            ? Image.file(
                File(upload.thumbnailPath!),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
              )
            : _buildDefaultThumbnail(),
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: const Icon(
        Icons.videocam,
        color: Colors.white54,
        size: 24,
      ),
    );
  }

  Widget _buildTitleAndMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          upload.title ?? 'Untitled Video',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              _formatFileSize(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            Text(
              _formatTimestamp(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusAndProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatusBadge(),
            const Spacer(),
            if (upload.uploadProgress != null && _isActiveUpload()) 
              Text(
                '${(upload.uploadProgress! * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (showProgress && upload.uploadProgress != null && _isActiveUpload()) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: upload.uploadProgress,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
            minHeight: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge() {
    final (statusText, statusColor) = _getStatusInfo();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[300],
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              upload.errorMessage!,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (upload.status == UploadStatus.failed && onRetry != null)
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: Colors.orange, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Retry Upload',
          ),
        
        if (_canCancel() && onCancel != null)
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Cancel Upload',
          ),
        
        if (_canDelete() && onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Delete from History',
          ),
      ],
    );
  }

  String _formatFileSize() {
    try {
      final file = File(upload.localVideoPath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024) return '${bytes}B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      // File may not exist anymore
    }
    return 'Unknown size';
  }

  String _formatTimestamp() {
    final now = DateTime.now();
    final diff = now.difference(upload.createdAt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${upload.createdAt.month}/${upload.createdAt.day}';
  }

  (String, Color) _getStatusInfo() {
    switch (upload.status) {
      case UploadStatus.pending:
        return ('Queued', Colors.blue);
      case UploadStatus.uploading:
        return ('Uploading', Colors.orange);
      case UploadStatus.processing:
        return ('Processing', Colors.purple);
      case UploadStatus.readyToPublish:
        return ('Publishing', Colors.cyan);
      case UploadStatus.published:
        return ('Published', Colors.green);
      case UploadStatus.failed:
        return ('Failed', Colors.red);
    }
  }

  Color _getProgressColor() {
    switch (upload.status) {
      case UploadStatus.uploading:
        return Colors.orange;
      case UploadStatus.processing:
        return Colors.purple;
      case UploadStatus.readyToPublish:
        return Colors.cyan;
      default:
        return Colors.blue;
    }
  }

  bool _isActiveUpload() {
    return upload.status == UploadStatus.uploading ||
           upload.status == UploadStatus.processing ||
           upload.status == UploadStatus.readyToPublish;
  }

  bool _canCancel() {
    return upload.status == UploadStatus.pending ||
           upload.status == UploadStatus.uploading;
  }

  bool _canDelete() {
    return upload.status == UploadStatus.published ||
           upload.status == UploadStatus.failed;
  }
}