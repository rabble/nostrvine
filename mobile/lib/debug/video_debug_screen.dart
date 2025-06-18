// ABOUTME: Debug screen for testing video URL loading and troubleshooting video player issues
// ABOUTME: Provides tools to test video URLs directly and inspect loading behavior on Flutter web

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoDebugScreen extends StatefulWidget {
  const VideoDebugScreen({super.key});

  @override
  State<VideoDebugScreen> createState() => _VideoDebugScreenState();
}

class _VideoDebugScreenState extends State<VideoDebugScreen> {
  final TextEditingController _urlController = TextEditingController();
  VideoPlayerController? _controller;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  DateTime? _startTime;
  DateTime? _endTime;

  // Pre-populate with a test URL
  @override
  void initState() {
    super.initState();
    _urlController.text = 'https://blossom.primal.net/8eff9145361526e4f4e47de57531761c4e0cda80e70d65bb4f5557a64650c226.mp4';
  }

  @override
  void dispose() {
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  /// Wait for controller to be fully ready with polling mechanism
  Future<void> _waitForControllerReady() async {
    const maxWaitTime = Duration(seconds: 3);
    const pollInterval = Duration(milliseconds: 10);
    final startTime = DateTime.now();
    
    while (_controller != null && !_controller!.value.isInitialized) {
      if (DateTime.now().difference(startTime) > maxWaitTime) {
        debugPrint('⚠️ DEBUG TIMEOUT: Controller never became ready after ${maxWaitTime.inSeconds}s');
        break;
      }
      
      await Future.delayed(pollInterval);
    }
    
    if (_controller?.value.isInitialized == true) {
      debugPrint('✅ Debug controller state fully synchronized');
    }
  }

  Future<void> _testVideoUrl() async {
    if (_urlController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a video URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _startTime = DateTime.now();
      _endTime = null;
    });

    try {
      // Dispose previous controller
      _controller?.dispose();
      
      debugPrint('🧪 Testing video URL: ${_urlController.text}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_urlController.text),
      );

      // Initialize with timeout
      await Future.any([
        _controller!.initialize(),
        Future.delayed(const Duration(seconds: 15)).then((_) => 
          throw TimeoutException('Video initialization timeout after 15 seconds', const Duration(seconds: 15))),
      ]);

      _endTime = DateTime.now();
      final duration = _endTime!.difference(_startTime!);

      // CRITICAL: Wait for controller state to be fully synchronized
      await _waitForControllerReady();
      
      // Double-check controller is ready before using
      if (!_controller!.value.isInitialized) {
        throw Exception('CRITICAL RACE CONDITION: Debug controller never became ready after initialization');
      }
      
      setState(() {
        _isLoading = false;
        _successMessage = 'Video loaded successfully in ${duration.inMilliseconds}ms\n'
            'Resolution: ${_controller!.value.size.width.toInt()}x${_controller!.value.size.height.toInt()}\n'
            'Duration: ${_controller!.value.duration.toString()}';
      });

      _controller!.setLooping(true);
      
      // Final safety check before play
      if (_controller!.value.isInitialized) {
        _controller!.play();
      } else {
        debugPrint('⚠️ Debug controller not ready for play after initialization');
      }

    } catch (error) {
      _endTime = DateTime.now();
      final duration = _endTime!.difference(_startTime!);

      debugPrint('🚨 Video test failed: $error');
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load video after ${duration.inMilliseconds}ms:\n$error';
      });

      _controller?.dispose();
      _controller = null;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Debug Tool'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Video URL Loading',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // URL Input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Video URL',
                border: OutlineInputBorder(),
                hintText: 'Enter video URL to test...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testVideoUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Testing...'),
                        ],
                      )
                    : const Text('Test Video URL'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Results
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _copyToClipboard(_errorMessage!),
                          child: const Text('Copy'),
                        ),
                      ],
                    ),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_successMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Success',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _copyToClipboard(_successMessage!),
                          child: const Text('Copy'),
                        ),
                      ],
                    ),
                    Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Video Player Preview
            if (_controller != null && _controller!.value.isInitialized)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              )
            else if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading video...'),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Enter a video URL and tap "Test Video URL" to preview',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}