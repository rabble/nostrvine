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
import '../utils/unified_logger.dart';

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
  bool _isExpiringPost = false;
  int _expirationHours = 24;
  
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
    Log.debug('Initializing video preview: ${widget.videoFile.path}', name: 'VideoMetadataScreen', category: LogCategory.ui);
    Log.debug('� File exists: ${widget.videoFile.existsSync()}', name: 'VideoMetadataScreen', category: LogCategory.ui);
    Log.debug('� File size: ${widget.videoFile.existsSync() ? widget.videoFile.lengthSync() : 0} bytes', name: 'VideoMetadataScreen', category: LogCategory.ui);
    
    _videoController = VideoPlayerController.file(widget.videoFile);
    try {
      await _videoController.initialize();
      Log.info('Video initialized: ${_videoController.value.size}', name: 'VideoMetadataScreen', category: LogCategory.ui);
      await _videoController.setLooping(true);
      await _videoController.play();
      setState(() => _isVideoInitialized = true);
    } catch (e) {
      Log.error('Failed to initialize video: $e', name: 'VideoMetadataScreen', category: LogCategory.ui);
      Log.verbose('� Stack trace: ${StackTrace.current}', name: 'VideoMetadataScreen', category: LogCategory.ui);
      // Still update UI to show error state
      setState(() => _isVideoInitialized = false);
    }
  }
  
  Widget _buildVideoPreview() {
    if (_isVideoInitialized && _videoController.value.isInitialized) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController.value.size.width,
            height: _videoController.value.size.height,
            child: VideoPlayer(_videoController),
          ),
        ),
      );
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
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: const Text(
          'Add Details',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
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
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress bar at the top (always visible)
          if (_currentUploadId != null)
            Consumer<UploadManager>(
              builder: (context, uploadManager, child) {
                final upload = uploadManager.getUpload(_currentUploadId!);
                if (upload == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Colors.grey[900],
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: upload.progressValue,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(VineTheme.vineGreen),
                        minHeight: 3,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_upload, color: VineTheme.vineGreen, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              upload.status == UploadStatus.uploading
                                  ? 'Uploading ${(upload.progressValue * 100).toInt()}%'
                                  : upload.status == UploadStatus.readyToPublish
                                      ? 'Upload complete - Ready to publish'
                                      : upload.statusText,
                              style: const TextStyle(color: VineTheme.vineGreen, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.duration.inSeconds}s • ${_getFileSize()}',
                              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          
          // Video preview - smaller to save space
          ClipRect(
            child: Container(
              height: screenHeight * 0.25, // 25% of screen height
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildVideoPreview(),
                  ),
                ],
              ),
            ),
          ),
          
          // Form fields with better spacing
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title field with integrated counter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Title',
                                  style: TextStyle(
                                    color: VineTheme.secondaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${_titleController.text.length}/100',
                                  style: TextStyle(
                                    color: VineTheme.secondaryText.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _titleController,
                              enabled: true,
                              autofocus: false,
                              enableInteractiveSelection: true,
                              style: const TextStyle(
                                color: VineTheme.primaryText,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Give your vine a catchy title',
                                hintStyle: TextStyle(
                                  color: VineTheme.secondaryText.withValues(alpha: 0.5),
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: VineTheme.secondaryText.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: VineTheme.vineGreen),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              maxLength: 100,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                                return const SizedBox.shrink(); // Hide default counter
                              },
                              onChanged: (_) => setState(() {}), // Update counter
                            ),
                          ],
                        ),
                        
                        Divider(color: VineTheme.secondaryText.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        
                        // Description field with integrated counter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Description (optional)',
                                  style: TextStyle(
                                    color: VineTheme.secondaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${_descriptionController.text.length}/500',
                                  style: TextStyle(
                                    color: VineTheme.secondaryText.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _descriptionController,
                              enabled: true,
                              enableInteractiveSelection: true,
                              style: const TextStyle(
                                color: VineTheme.primaryText,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tell viewers about your vine',
                                hintStyle: TextStyle(
                                  color: VineTheme.secondaryText.withValues(alpha: 0.5),
                                  fontSize: 15,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: VineTheme.secondaryText.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: VineTheme.vineGreen),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              maxLines: 2,
                              maxLength: 500,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                                return const SizedBox.shrink(); // Hide default counter
                              },
                              onChanged: (_) => setState(() {}), // Update counter
                            ),
                          ],
                        ),
                        
                        Divider(color: VineTheme.secondaryText.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        
                        // Hashtags section - more compact
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hashtags',
                              style: TextStyle(
                                color: VineTheme.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Hashtag chips - horizontal scroll if needed
                            SizedBox(
                              height: 32,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  // Default openvine tag
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Chip(
                                      label: const Text('#openvine', style: TextStyle(fontSize: 13)),
                                      backgroundColor: VineTheme.vineGreen.withValues(alpha: 0.2),
                                      labelStyle: const TextStyle(color: VineTheme.vineGreen),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  // User added tags
                                  ..._hashtags.map((tag) => Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Chip(
                                      label: Text('#$tag', style: const TextStyle(fontSize: 13)),
                                      backgroundColor: VineTheme.vineGreen.withValues(alpha: 0.2),
                                      labelStyle: const TextStyle(color: VineTheme.vineGreen),
                                      deleteIcon: const Icon(Icons.close, size: 16),
                                      deleteIconColor: VineTheme.vineGreen,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onDeleted: () {
                                        setState(() {
                                          _hashtags.remove(tag);
                                        });
                                      },
                                    ),
                                  )),
                                  // Add hashtag button
                                  if (_hashtags.length < 5) // Limit to 5 custom tags
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        label: const Text('+ Add', style: TextStyle(fontSize: 13)),
                                        backgroundColor: Colors.grey[850],
                                        labelStyle: TextStyle(color: VineTheme.secondaryText),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onPressed: () => _showHashtagDialog(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Divider(color: VineTheme.secondaryText.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        
                        // Expiring post toggle
                        Row(
                          children: [
                            Text(
                              'Expiring Post',
                              style: TextStyle(
                                color: VineTheme.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _isExpiringPost,
                              onChanged: (value) {
                                setState(() {
                                  _isExpiringPost = value;
                                });
                              },
                              activeColor: VineTheme.vineGreen,
                            ),
                          ],
                        ),
                        if (_isExpiringPost) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Expires in:',
                            style: TextStyle(
                              color: VineTheme.secondaryText.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildExpirationOption('1 hour', 1),
                                const SizedBox(width: 8),
                                _buildExpirationOption('1 day', 24),
                                const SizedBox(width: 8),
                                _buildExpirationOption('1 week', 168),
                                const SizedBox(width: 8),
                                _buildExpirationOption('1 month', 720),
                                const SizedBox(width: 8),
                                _buildExpirationOption('1 year', 8760),
                              ],
                            ),
                          ),
                        ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpirationOption(String label, int hours) {
    final isSelected = _expirationHours == hours;
    return GestureDetector(
      onTap: () {
        setState(() {
          _expirationHours = hours;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? VineTheme.vineGreen : Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? null 
              : Border.all(color: VineTheme.secondaryText.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : VineTheme.secondaryText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  void _addHashtag() {
    final tag = _hashtagController.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_hashtags.contains(tag) && tag != 'openvine') {
      setState(() {
        _hashtags.add(tag);
        _hashtagController.clear();
      });
    }
  }
  
  void _showHashtagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Add Hashtag',
          style: TextStyle(color: VineTheme.primaryText),
        ),
        content: TextField(
          controller: _hashtagController,
          autofocus: true,
          style: const TextStyle(color: VineTheme.primaryText),
          decoration: InputDecoration(
            hintText: 'Enter hashtag',
            hintStyle: TextStyle(color: VineTheme.secondaryText.withValues(alpha: 0.5)),
            prefixText: '#',
            prefixStyle: const TextStyle(color: VineTheme.vineGreen),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: VineTheme.secondaryText),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: VineTheme.vineGreen),
            ),
          ),
          onSubmitted: (_) {
            _addHashtag();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _hashtagController.clear();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              _addHashtag();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Add',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
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
        hashtags: ['openvine'],
      );
      
      setState(() {
        _currentUploadId = upload.id;
      });
      
      Log.info('Background upload started: ${upload.id}', name: 'VideoMetadataScreen', category: LogCategory.ui);
    } catch (e) {
      Log.error('Failed to start background upload: $e', name: 'VideoMetadataScreen', category: LogCategory.ui);
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
    
    // Always include openvine tag
    final allHashtags = ['openvine', ..._hashtags];
    
    // Calculate expiration timestamp if enabled
    int? expirationTimestamp;
    if (_isExpiringPost) {
      final now = DateTime.now();
      final expirationDate = now.add(Duration(hours: _expirationHours));
      expirationTimestamp = expirationDate.millisecondsSinceEpoch ~/ 1000;
    }
    
    // TODO: Update the upload metadata with the final title/description
    // For now, the upload continues with the original metadata
    
    // Just navigate back to the feed
    if (mounted) {
      Navigator.of(context).pop({
        'uploadId': _currentUploadId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'hashtags': allHashtags,
        'expirationTimestamp': expirationTimestamp,
      });
    }
  }
}