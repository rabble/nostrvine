// ABOUTME: Publishing progress UI components for vine upload and processing
// ABOUTME: Shows real-time progress and status during vine publishing to Nostr

import 'package:flutter/material.dart';
import '../services/vine_publishing_service.dart';

/// Widget showing vine publishing progress with animations
class PublishingProgressDialog extends StatelessWidget {
  final VinePublishingService publishingService;
  final VoidCallback? onCancel;
  final bool showCancelButton;
  
  const PublishingProgressDialog({
    super.key,
    required this.publishingService,
    this.onCancel,
    this.showCancelButton = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: publishingService,
      builder: (context, _) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 12),
              Text(
                _getDialogTitle(),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                publishingService.statusMessage ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (publishingService.state == PublishingState.error) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[900]?.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Publishing failed. Please try again.',
                          style: TextStyle(color: Colors.red[300], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (showCancelButton && publishingService.isPublishing)
              TextButton(
                onPressed: () {
                  publishingService.cancelPublishing();
                  onCancel?.call();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            if (publishingService.state == PublishingState.completed)
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done', style: TextStyle(color: Colors.green)),
              ),
            if (publishingService.state == PublishingState.error)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildStatusIcon() {
    switch (publishingService.state) {
      case PublishingState.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case PublishingState.error:
        return const Icon(Icons.error, color: Colors.red, size: 24);
      case PublishingState.queuedOffline:
        return const Icon(Icons.cloud_off, color: Colors.orange, size: 24);
      default:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        );
    }
  }
  
  Widget _buildProgressIndicator() {
    if (publishingService.state == PublishingState.completed) {
      return Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 30),
      );
    }
    
    if (publishingService.state == PublishingState.error) {
      return Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 30),
      );
    }
    
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: publishingService.progress,
              strokeWidth: 6,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
          Text(
            '${(publishingService.progress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDialogTitle() {
    switch (publishingService.state) {
      case PublishingState.idle:
        return 'Ready to Publish';
      case PublishingState.creatingGif:
        return 'Creating GIF';
      case PublishingState.uploadingToBackend:
        return 'Uploading';
      case PublishingState.waitingForProcessing:
        return 'Processing';
      case PublishingState.broadcastingToNostr:
        return 'Publishing';
      case PublishingState.retrying:
        return 'Retrying';
      case PublishingState.queuedOffline:
        return 'Queued';
      case PublishingState.completed:
        return 'Published!';
      case PublishingState.error:
        return 'Failed';
    }
  }
}

/// Compact progress widget for in-app use
class PublishingProgressWidget extends StatelessWidget {
  final VinePublishingService publishingService;
  final bool showPercentage;
  final bool showStatusText;
  final double? width;
  final double? height;
  
  const PublishingProgressWidget({
    super.key,
    required this.publishingService,
    this.showPercentage = true,
    this.showStatusText = true,
    this.width,
    this.height,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: publishingService,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildCompactStatusIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCompactTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (showStatusText && publishingService.statusMessage != null)
                          Text(
                            publishingService.statusMessage!,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (showPercentage && publishingService.isPublishing)
                    Text(
                      '${(publishingService.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if (publishingService.isPublishing) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: publishingService.progress,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCompactStatusIcon() {
    switch (publishingService.state) {
      case PublishingState.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case PublishingState.error:
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case PublishingState.queuedOffline:
        return const Icon(Icons.cloud_off, color: Colors.orange, size: 20);
      default:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        );
    }
  }
  
  String _getCompactTitle() {
    switch (publishingService.state) {
      case PublishingState.idle:
        return 'Ready';
      case PublishingState.creatingGif:
        return 'Creating GIF';
      case PublishingState.uploadingToBackend:
        return 'Uploading';
      case PublishingState.waitingForProcessing:
        return 'Processing';
      case PublishingState.broadcastingToNostr:
        return 'Publishing to Nostr';
      case PublishingState.retrying:
        return 'Retrying';
      case PublishingState.queuedOffline:
        return 'Queued for later';
      case PublishingState.completed:
        return 'Published successfully';
      case PublishingState.error:
        return 'Publishing failed';
    }
  }
}

/// Bottom sheet progress display
class PublishingProgressBottomSheet extends StatelessWidget {
  final VinePublishingService publishingService;
  final VoidCallback? onRetry;
  final VoidCallback? onViewPublished;
  
  const PublishingProgressBottomSheet({
    super.key,
    required this.publishingService,
    this.onRetry,
    this.onViewPublished,
  });
  
  static void show(
    BuildContext context, {
    required VinePublishingService publishingService,
    VoidCallback? onRetry,
    VoidCallback? onViewPublished,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => PublishingProgressBottomSheet(
        publishingService: publishingService,
        onRetry: onRetry,
        onViewPublished: onViewPublished,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: publishingService,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Progress content
                PublishingProgressWidget(
                  publishingService: publishingService,
                  width: double.infinity,
                ),
                
                const SizedBox(height: 24),
                
                // Actions
                if (publishingService.state == PublishingState.completed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onViewPublished?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View Published Vine'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ] else if (publishingService.state == PublishingState.error) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ] else if (publishingService.isPublishing) ...[
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        publishingService.cancelPublishing();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel Publishing'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}