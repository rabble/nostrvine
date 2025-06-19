// ABOUTME: Main upload status panel showing active uploads, queue, and history
// ABOUTME: Organizes uploads by status and provides comprehensive management interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pending_upload.dart';
import '../services/upload_manager.dart';
import 'upload_list_item.dart';

class UploadStatusPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const UploadStatusPanel({
    super.key,
    this.onClose,
  });

  @override
  State<UploadStatusPanel> createState() => _UploadStatusPanelState();
}

class _UploadStatusPanelState extends State<UploadStatusPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: Consumer<UploadManager>(
              builder: (context, uploadManager, child) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveUploadsTab(uploadManager),
                    _buildQueueTab(uploadManager),
                    _buildHistoryTab(uploadManager),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Text(
            'Upload Manager',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Consumer<UploadManager>(
            builder: (context, uploadManager, child) {
              final activeCount = _getActiveUploadsCount(uploadManager);
              if (activeCount > 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Text(
                    '$activeCount active',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Consumer<UploadManager>(
      builder: (context, uploadManager, child) {
        final activeCount = _getActiveUploadsCount(uploadManager);
        final queueCount = _getQueueCount(uploadManager);
        final historyCount = _getHistoryCount(uploadManager);

        return TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          indicatorColor: Colors.purple,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        activeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Queue'),
                  if (queueCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        queueCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('History'),
                  if (historyCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        historyCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveUploadsTab(UploadManager uploadManager) {
    final activeUploads = uploadManager.pendingUploads
        .where((upload) =>
            upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.processing ||
            upload.status == UploadStatus.readyToPublish)
        .toList();

    if (activeUploads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_upload_outlined,
        title: 'No Active Uploads',
        subtitle: 'Your uploads will appear here when in progress',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: activeUploads.length,
      itemBuilder: (context, index) {
        final upload = activeUploads[index];
        return UploadListItem(
          upload: upload,
          onCancel: upload.status == UploadStatus.uploading
              ? () => _cancelUpload(uploadManager, upload)
              : null,
          onTap: () => _showUploadDetails(upload),
        );
      },
    );
  }

  Widget _buildQueueTab(UploadManager uploadManager) {
    final queuedUploads = uploadManager.getUploadsByStatus(UploadStatus.pending);

    if (queuedUploads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.queue,
        title: 'Upload Queue Empty',
        subtitle: 'Pending uploads will appear here',
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[300], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Uploads are processed automatically in order',
                  style: TextStyle(
                    color: Colors.blue[300],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: queuedUploads.length,
            itemBuilder: (context, index) {
              final upload = queuedUploads[index];
              return UploadListItem(
                upload: upload,
                onCancel: () => _cancelUpload(uploadManager, upload),
                onTap: () => _showUploadDetails(upload),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(UploadManager uploadManager) {
    final completedUploads = uploadManager.pendingUploads
        .where((upload) =>
            upload.status == UploadStatus.published ||
            upload.status == UploadStatus.failed)
        .take(20) // Limit to recent 20 items
        .toList();

    if (completedUploads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Upload History',
        subtitle: 'Completed and failed uploads will appear here',
      );
    }

    return Column(
      children: [
        _buildHistoryStats(uploadManager),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: completedUploads.length,
            itemBuilder: (context, index) {
              final upload = completedUploads[index];
              return UploadListItem(
                upload: upload,
                onRetry: upload.status == UploadStatus.failed
                    ? () => _retryUpload(uploadManager, upload)
                    : null,
                onDelete: () => _deleteUpload(uploadManager, upload),
                onTap: () => _showUploadDetails(upload),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryStats(UploadManager uploadManager) {
    final allUploads = uploadManager.pendingUploads;
    final publishedCount = allUploads.where((u) => u.status == UploadStatus.published).length;
    final failedCount = allUploads.where((u) => u.status == UploadStatus.failed).length;
    final totalCompleted = publishedCount + failedCount;
    final successRate = totalCompleted > 0 ? (publishedCount / totalCompleted * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Success Rate',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$successRate%',
                  style: TextStyle(
                    color: successRate >= 80 ? Colors.green : Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Published',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Text(
                  publishedCount.toString(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Text(
                  failedCount.toString(),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _getActiveUploadsCount(UploadManager uploadManager) {
    return uploadManager.pendingUploads
        .where((upload) =>
            upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.processing ||
            upload.status == UploadStatus.readyToPublish)
        .length;
  }

  int _getQueueCount(UploadManager uploadManager) {
    return uploadManager.getUploadsByStatus(UploadStatus.pending).length;
  }

  int _getHistoryCount(UploadManager uploadManager) {
    return uploadManager.pendingUploads
        .where((upload) =>
            upload.status == UploadStatus.published ||
            upload.status == UploadStatus.failed)
        .length;
  }

  Future<void> _cancelUpload(UploadManager uploadManager, PendingUpload upload) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Cancel Upload',
      message: 'Are you sure you want to cancel this upload?',
      confirmText: 'Cancel Upload',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await uploadManager.cancelUpload(upload.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel upload: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _retryUpload(UploadManager uploadManager, PendingUpload upload) async {
    try {
      await uploadManager.retryUpload(upload.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload restarted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUpload(UploadManager uploadManager, PendingUpload upload) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Delete Upload',
      message: 'Remove this upload from history? This cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await uploadManager.deleteUpload(upload.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload deleted from history'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete upload: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showUploadDetails(PendingUpload upload) {
    showDialog(
      context: context,
      builder: (context) => _UploadDetailsDialog(upload: upload),
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadDetailsDialog extends StatelessWidget {
  final PendingUpload upload;

  const _UploadDetailsDialog({required this.upload});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Upload Details', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Title', upload.title ?? 'Untitled'),
            _buildDetailRow('Status', upload.status.toString().split('.').last),
            _buildDetailRow('Created', upload.createdAt.toString()),
            if (upload.uploadProgress != null)
              _buildDetailRow('Progress', '${(upload.uploadProgress! * 100).toInt()}%'),
            if (upload.cloudinaryPublicId != null)
              _buildDetailRow('Public ID', upload.cloudinaryPublicId!),
            if (upload.nostrEventId != null)
              _buildDetailRow('Nostr Event', upload.nostrEventId!),
            if (upload.errorMessage != null)
              _buildDetailRow('Error', upload.errorMessage!, isError: true),
            if (upload.hashtags?.isNotEmpty == true)
              _buildDetailRow('Hashtags', upload.hashtags!.join(', ')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: isError ? Colors.red[300] : Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}