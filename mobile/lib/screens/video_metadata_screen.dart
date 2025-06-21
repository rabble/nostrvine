// ABOUTME: Video metadata entry screen for adding title, description, and hashtags to recorded videos
// ABOUTME: Displays video preview alongside input fields for enhanced user experience

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../services/upload_manager.dart';
import '../widgets/hashtag_input_widget.dart';
import '../widgets/character_counter_widget.dart';

class VideoMetadataScreen extends StatefulWidget {
  final File videoFile;
  final VoidCallback? onCancel;
  final VoidCallback? onPublish;

  const VideoMetadataScreen({
    super.key,
    required this.videoFile,
    this.onCancel,
    this.onPublish,
  });

  @override
  State<VideoMetadataScreen> createState() => _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends State<VideoMetadataScreen> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isUploading = false;
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  
  List<String> _hashtags = [];
  
  static const int _maxTitleLength = 100;
  static const int _maxDescriptionLength = 280;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _controller!.setLooping(true);
        _playVideo();
      }
    } catch (e) {
      debugPrint('❌ Error initializing video preview: $e');
    }
  }

  void _playVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  bool get _isFormValid {
    return _titleController.text.trim().isNotEmpty &&
           _titleController.text.length <= _maxTitleLength &&
           _descriptionController.text.length <= _maxDescriptionLength;
  }

  Future<void> _publishVideo() async {
    if (!_isFormValid || _isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final uploadManager = context.read<UploadManager>();
      
      // Get current user's pubkey from NostrService
      // For now, we'll use a placeholder - this should be updated when NostrService is accessible
      const userPubkey = 'placeholder_pubkey';
      
      await uploadManager.startUpload(
        videoFile: widget.videoFile,
        nostrPubkey: userPubkey,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        hashtags: _hashtags,
      );

      if (mounted) {
        widget.onPublish?.call();
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded! Publishing in background...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error uploading video: $e');
      
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isUploading ? null : () {
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Add Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isFormValid && !_isUploading ? _publishVideo : null,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Publish',
                    style: TextStyle(
                      color: _isFormValid ? Colors.purple : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Preview Section
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildVideoPreview(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Title',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          CharacterCounterWidget(
                            currentLength: _titleController.text.length,
                            maxLength: _maxTitleLength,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        style: const TextStyle(color: Colors.white),
                        maxLength: _maxTitleLength,
                        decoration: InputDecoration(
                          hintText: 'Give your video a catchy title...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '', // Hide default counter
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          CharacterCounterWidget(
                            currentLength: _descriptionController.text.length,
                            maxLength: _maxDescriptionLength,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocus,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 4,
                        maxLength: _maxDescriptionLength,
                        decoration: InputDecoration(
                          hintText: 'Tell viewers what your video is about...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '', // Hide default counter
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Hashtags Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      HashtagInputWidget(
                        initialValue: _hashtags.join(' '),
                        onHashtagsChanged: (hashtags) {
                          setState(() {
                            _hashtags = hashtags;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[800],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 12),
              Text(
                'Loading preview...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          
          // Play/Pause Overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Mute indicator (videos are always muted in preview)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.volume_off,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}