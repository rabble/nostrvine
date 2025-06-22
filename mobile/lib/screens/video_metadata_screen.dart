// ABOUTME: Screen for adding metadata to recorded videos before publishing
// ABOUTME: Allows users to add title, description, and hashtags to their vines

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../theme/vine_theme.dart';
import '../models/pending_upload.dart';
import '../services/upload_manager.dart';
import '../services/auth_service.dart';

class VideoMetadataScreen extends StatefulWidget {
  final File videoFile;
  final Duration duration;
  
  const VideoMetadataScreen({
    super.key,
    required this.videoFile,
    required this.duration,
  });
  
  @override
  State<VideoMetadataScreen> createState() => _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends State<VideoMetadataScreen> {
  late VideoPlayerController _videoController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final List<String> _hashtags = [];
  bool _isVideoInitialized = false;
  String? _currentUploadId;
  
  @override
  void initState() {
    super.initState();
    // Delay initialization to ensure file is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
      _startBackgroundUpload();
    });
  }
  
  @override
  void dispose() {
    _videoController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeVideo() async {
    debugPrint('🎬 Initializing video preview: ${widget.videoFile.path}');
    debugPrint('📁 File exists: ${widget.videoFile.existsSync()}');
    debugPrint('📏 File size: ${widget.videoFile.existsSync() ? widget.videoFile.lengthSync() : 0} bytes');
    
    _videoController = VideoPlayerController.file(widget.videoFile);
    try {
      await _videoController.initialize();
      debugPrint('✅ Video initialized: ${_videoController.value.size}');
      await _videoController.setLooping(true);
      await _videoController.play();
      setState(() => _isVideoInitialized = true);
    } catch (e) {
      debugPrint('❌ Failed to initialize video: $e');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      // Still update UI to show error state
      setState(() => _isVideoInitialized = false);
    }
  }
  
  Widget _buildVideoPreview() {
    if (_isVideoInitialized && _videoController.value.isInitialized) {
      return VideoPlayer(_videoController);
    }
    
    // Check if file exists
    if (!widget.videoFile.existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Video file not found',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back', style: TextStyle(color: VineTheme.vineGreen)),
            ),
          ],
        ),
      );
    }
    
    // Loading state
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        title: const Text(
          'Add Details',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _publishVideo,
            child: const Text(
              'PUBLISH',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video preview
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _buildVideoPreview(),
                  ),
                ),
            
            // Metadata form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: VineTheme.primaryText),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: VineTheme.secondaryText),
                      hintText: 'Give your vine a title',
                      hintStyle: TextStyle(color: VineTheme.secondaryText.withValues(alpha: 0.5)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: VineTheme.secondaryText),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: VineTheme.vineGreen),
                      ),
                    ),
                    maxLength: 100,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: VineTheme.primaryText),
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: TextStyle(color: VineTheme.secondaryText),
                      hintText: 'Add a description',
                      hintStyle: TextStyle(color: VineTheme.secondaryText.withValues(alpha: 0.5)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: VineTheme.secondaryText),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: VineTheme.vineGreen),
                      ),
                    ),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Hashtags
                  TextField(
                    controller: _hashtagController,
                    style: const TextStyle(color: VineTheme.primaryText),
                    decoration: InputDecoration(
                      labelText: 'Add hashtags',
                      labelStyle: TextStyle(color: VineTheme.secondaryText),
                      hintText: 'Type a hashtag and press enter',
                      hintStyle: TextStyle(color: VineTheme.secondaryText.withValues(alpha: 0.5)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: VineTheme.secondaryText),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: VineTheme.vineGreen),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add, color: VineTheme.vineGreen),
                        onPressed: _addHashtag,
                      ),
                    ),
                    onSubmitted: (_) => _addHashtag(),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Hashtag chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Default nostrvine tag
                      Chip(
                        label: const Text('#nostrvine'),
                        backgroundColor: VineTheme.vineGreen.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: VineTheme.vineGreen),
                      ),
                      // User added tags
                      ..._hashtags.map((tag) => Chip(
                        label: Text('#$tag'),
                        backgroundColor: VineTheme.vineGreen.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: VineTheme.vineGreen),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        deleteIconColor: VineTheme.vineGreen,
                        onDeleted: () {
                          setState(() {
                            _hashtags.remove(tag);
                          });
                        },
                      )),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Video info and upload status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: VineTheme.secondaryText, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: ${widget.duration.inSeconds}s • Size: ${_getFileSize()}',
                              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
                            ),
                          ],
                        ),
                        if (_currentUploadId != null) ...[
                          const SizedBox(height: 8),
                          Consumer<UploadManager>(
                            builder: (context, uploadManager, child) {
                              final upload = uploadManager.getUpload(_currentUploadId!);
                              if (upload == null) return const SizedBox.shrink();
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.cloud_upload, color: VineTheme.vineGreen, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          upload.status == UploadStatus.uploading
                                              ? 'Uploading ${(upload.progressValue * 100).toInt()}%'
                                              : upload.status == UploadStatus.readyToPublish
                                                  ? 'Upload complete'
                                                  : upload.statusText,
                                          style: const TextStyle(color: VineTheme.vineGreen, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: upload.progressValue,
                                    backgroundColor: Colors.grey[700],
                                    valueColor: const AlwaysStoppedAnimation<Color>(VineTheme.vineGreen),
                                    minHeight: 2,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
}
  
  void _addHashtag() {
    final tag = _hashtagController.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_hashtags.contains(tag) && tag != 'nostrvine') {
      setState(() {
        _hashtags.add(tag);
        _hashtagController.clear();
      });
    }
  }
  
  String _getFileSize() {
    final bytes = widget.videoFile.lengthSync();
    final mb = bytes / 1024 / 1024;
    return '${mb.toStringAsFixed(1)}MB';
  }
  
  /// Start upload immediately in the background
  Future<void> _startBackgroundUpload() async {
    try {
      final uploadManager = context.read<UploadManager>();
      final authService = context.read<AuthService>();
      
      // Get user's public key
      final userPubkey = authService.currentPublicKeyHex ?? 'anonymous';
      
      // Start the upload with placeholder metadata (will update when user publishes)
      final upload = await uploadManager.startUpload(
        videoFile: widget.videoFile,
        nostrPubkey: userPubkey,
        title: 'Untitled', // Placeholder title
        description: '',
        hashtags: ['nostrvine'],
      );
      
      setState(() {
        _currentUploadId = upload.id;
      });
      
      debugPrint('🚀 Background upload started: ${upload.id}');
    } catch (e) {
      debugPrint('❌ Failed to start background upload: $e');
    }
  }
  
  Future<void> _publishVideo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Always include nostrvine tag
    final allHashtags = ['nostrvine', ..._hashtags];
    
    // TODO: Update the upload metadata with the final title/description
    // For now, the upload continues with the original metadata
    
    // Just navigate back to the feed
    if (mounted) {
      Navigator.of(context).pop({
        'uploadId': _currentUploadId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'hashtags': allHashtags,
      });
    }
  }
}