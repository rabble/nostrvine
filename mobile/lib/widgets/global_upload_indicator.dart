// ABOUTME: Global upload progress indicator that shows on all screens
// ABOUTME: Displays active uploads as a small overlay that can be tapped for details

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pending_upload.dart';
import '../services/upload_manager.dart';
import '../theme/vine_theme.dart';
import 'upload_progress_indicator.dart';

/// Global upload indicator that shows active uploads
class GlobalUploadIndicator extends StatelessWidget {
  const GlobalUploadIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadManager>(
      builder: (context, uploadManager, child) {
        // Get active uploads (uploading, processing, or ready to publish)
        final activeUploads = uploadManager.pendingUploads
            .where((upload) => 
                upload.status == UploadStatus.uploading ||
                upload.status == UploadStatus.processing ||
                upload.status == UploadStatus.readyToPublish ||
                upload.status == UploadStatus.retrying)
            .toList();
        
        if (activeUploads.isEmpty) {
          return const SizedBox.shrink();
        }
        
        // Show the most recent upload
        final latestUpload = activeUploads.first;
        
        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => _showUploadDetails(context, activeUploads),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress indicator
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: latestUpload.progressValue,
                        strokeWidth: 2,
                        backgroundColor: Colors.grey[600],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          latestUpload.status == UploadStatus.failed 
                              ? Colors.red 
                              : VineTheme.vineGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Status text
                    Flexible(
                      child: Text(
                        _getStatusText(latestUpload, activeUploads.length),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Chevron if multiple uploads
                    if (activeUploads.length > 1) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _getStatusText(PendingUpload upload, int totalCount) {
    String baseText;
    
    switch (upload.status) {
      case UploadStatus.uploading:
        baseText = 'Uploading ${(upload.progressValue * 100).toInt()}%';
        break;
      case UploadStatus.processing:
        baseText = 'Processing video...';
        break;
      case UploadStatus.readyToPublish:
        baseText = 'Ready to publish';
        break;
      case UploadStatus.retrying:
        baseText = 'Retrying upload...';
        break;
      default:
        baseText = upload.statusText;
    }
    
    if (totalCount > 1) {
      baseText += ' (+${totalCount - 1} more)';
    }
    
    return baseText;
  }
  
  void _showUploadDetails(BuildContext context, List<PendingUpload> uploads) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VineTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Uploads (${uploads.length})',
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: VineTheme.secondaryText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // Upload list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: uploads.length,
                itemBuilder: (context, index) {
                  return UploadProgressIndicator(
                    upload: uploads[index],
                    showActions: true,
                    onCancel: () {
                      final uploadManager = context.read<UploadManager>();
                      uploadManager.cancelUpload(uploads[index].id);
                      Navigator.of(context).pop();
                    },
                    onRetry: () {
                      final uploadManager = context.read<UploadManager>();
                      uploadManager.retryUpload(uploads[index].id);
                    },
                    onDelete: () {
                      final uploadManager = context.read<UploadManager>();
                      uploadManager.deleteUpload(uploads[index].id);
                      if (uploads.length == 1) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}