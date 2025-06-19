// ABOUTME: Upload management screen with queue, history, and status tracking
// ABOUTME: Provides comprehensive upload visibility and management actions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pending_upload.dart';
import '../services/upload_manager.dart';
import '../widgets/upload_list_item.dart';

class UploadManagerScreen extends StatefulWidget {
  const UploadManagerScreen({super.key});

  @override
  State<UploadManagerScreen> createState() => _UploadManagerScreenState();
}

class _UploadManagerScreenState extends State<UploadManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UploadManager _uploadManager;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _uploadManager = context.read<UploadManager>();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Upload Manager',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        actions: [
          // Clear completed uploads
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _showClearCompletedDialog,
            tooltip: 'Clear Completed',
          ),
          // Retry all failed
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _retryAllFailed,
            tooltip: 'Retry Failed',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[500],
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Queue'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Consumer<UploadManager>(
        builder: (context, uploadManager, child) {
          return Column(
            children: [
              // Upload statistics panel
              _buildStatsPanel(uploadManager),
              
              // Tab view content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveUploads(uploadManager),
                    _buildQueuedUploads(uploadManager),
                    _buildUploadHistory(uploadManager),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsPanel(UploadManager uploadManager) {
    final uploads = uploadManager.pendingUploads;
    final activeCount = uploads.where((u) => 
        u.status == UploadStatus.uploading || 
        u.status == UploadStatus.processing).length;
    final queuedCount = uploads.where((u) => u.status == UploadStatus.pending).length;
    final failedCount = uploads.where((u) => u.status == UploadStatus.failed).length;
    final completedCount = uploads.where((u) => u.status == UploadStatus.published).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Active', activeCount, Colors.blue),
          _buildStatItem('Queue', queuedCount, Colors.orange),
          _buildStatItem('Failed', failedCount, Colors.red),
          _buildStatItem('Done', completedCount, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveUploads(UploadManager uploadManager) {
    final activeUploads = uploadManager.pendingUploads
        .where((upload) => 
            upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.processing)
        .toList();

    if (activeUploads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_upload,
        title: 'No Active Uploads',
        subtitle: 'When you start uploading videos, they\'ll appear here',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activeUploads.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final upload = activeUploads[index];
        return UploadListItem(
          upload: upload,
          onCancel: () => _cancelUpload(upload),
          onRetry: null, // No retry for active uploads
          showThumbnail: true,
          showProgress: true,
        );
      },
    );
  }

  Widget _buildQueuedUploads(UploadManager uploadManager) {
    final queuedUploads = uploadManager.pendingUploads
        .where((upload) => upload.status == UploadStatus.pending)
        .toList();

    if (queuedUploads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.queue,
        title: 'Upload Queue Empty',
        subtitle: 'Pending uploads will appear here before they start',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: queuedUploads.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final upload = queuedUploads[index];
        return UploadListItem(
          upload: upload,
          onCancel: () => _cancelUpload(upload),
          onRetry: null,
          showThumbnail: true,
          showProgress: false,
        );
      },
    );
  }

  Widget _buildUploadHistory(UploadManager uploadManager) {
    final historyUploads = uploadManager.pendingUploads
        .where((upload) => 
            upload.status == UploadStatus.published ||
            upload.status == UploadStatus.failed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first

    if (historyUploads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Upload History',
        subtitle: 'Completed and failed uploads will appear here',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: historyUploads.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final upload = historyUploads[index];
        return UploadListItem(
          upload: upload,
          onCancel: upload.status == UploadStatus.failed 
              ? () => _deleteUpload(upload) 
              : null,
          onRetry: upload.status == UploadStatus.failed 
              ? () => _retryUpload(upload) 
              : null,
          showThumbnail: true,
          showProgress: false,
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
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
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelUpload(PendingUpload upload) async {
    try {
      await _uploadManager.cancelUpload(upload.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload cancelled: ${upload.title ?? "Video"}'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel upload: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _retryUpload(PendingUpload upload) async {
    try {
      await _uploadManager.retryUpload(upload.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrying upload: ${upload.title ?? "Video"}'),
            backgroundColor: Colors.blue[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry upload: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _deleteUpload(PendingUpload upload) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Upload', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${upload.title ?? "this upload"}" from history? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _uploadManager.deleteUpload(upload.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: ${upload.title ?? "Video"}'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete upload: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  Future<void> _showClearCompletedDialog() async {
    final completed = _uploadManager.pendingUploads
        .where((u) => u.status == UploadStatus.published)
        .length;

    if (completed == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed uploads to clear'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Clear Completed', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove all $completed completed uploads from history?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.purple)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _uploadManager.clearCompletedUploads();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleared $completed completed uploads'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear uploads: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  Future<void> _retryAllFailed() async {
    final failed = _uploadManager.pendingUploads
        .where((u) => u.status == UploadStatus.failed)
        .toList();

    if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No failed uploads to retry'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _uploadManager.retryFailedUploads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrying ${failed.length} failed uploads'),
            backgroundColor: Colors.blue[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry uploads: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }
}