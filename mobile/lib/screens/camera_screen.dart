import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../services/gif_service.dart';
import '../services/nostr_service.dart';
import '../services/vine_publishing_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraService? _cameraService;
  final GifService _gifService = GifService();
  late final NostrService _nostrService;
  VinePublishingService? _publishingService;
  String? _errorMessage;
  GifResult? _lastGifResult;
  VineRecordingResult? _lastRecordingResult;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _cameraService?.dispose();
    _nostrService.dispose();
    _publishingService?.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // Initialize Nostr and publishing services
    _nostrService = NostrService();
    _publishingService = VinePublishingService(
      gifService: _gifService,
      nostrService: _nostrService,
    );
    
    // Initialize Nostr service
    try {
      await _nostrService.initialize();
      debugPrint('✅ Nostr service initialized');
    } catch (e) {
      debugPrint('⚠️ Nostr service initialization failed: $e');
      // Continue anyway - we can publish locally without Nostr
    }
    
    // Initialize camera
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraService = CameraService();
      await _cameraService!.initialize();
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _cameraService,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CameraService>(
          builder: (context, cameraService, _) {
            return Stack(
              children: [
                // Camera preview or error state
                Positioned.fill(
                  child: _buildCameraPreview(cameraService),
                ),

                // Top controls
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          // Offline queue indicator
                          if (_publishingService?.hasOfflineContent == true)
                            GestureDetector(
                              onTap: _showOfflineQueueDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_publishingService?.offlineQueueCount ?? 0}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Timer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getTimerText(cameraService),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => cameraService?.switchCamera(),
                      ),
                    ],
                  ),
                ),

                // Recording progress bar
                if (cameraService?.isRecording == true)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: cameraService?.recordingProgress ?? 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Side effects/filters panel
                Positioned(
                  right: 20,
                  top: MediaQuery.of(context).size.height * 0.3,
                  child: Column(
                    children: [
                      _buildEffectButton(Icons.face_retouching_natural, 'Beauty'),
                      const SizedBox(height: 20),
                      _buildEffectButton(Icons.filter_vintage, 'Filters'),
                      const SizedBox(height: 20),
                      _buildEffectButton(Icons.speed, 'Speed'),
                      const SizedBox(height: 20),
                      _buildEffectButton(Icons.timer, 'Timer'),
                    ],
                  ),
                ),

                // Recording state indicator (only show during manual processing, not auto-stop)
                if (cameraService?.state == RecordingState.processing && !cameraService!.isRecording)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4,
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Colors.purple),
                          SizedBox(height: 16),
                          Text(
                            'Processing frames...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom controls
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 30,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Recording duration display
                      if (cameraService?.isRecording == true)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'REC ${_formatDuration(cameraService?.recordingProgress ?? 0.0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Main controls row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery/Library button
                          GestureDetector(
                            onTap: _openGallery,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                          // Record button
                          GestureDetector(
                            onTapDown: (_) => _startRecording(cameraService),
                            onTapUp: (_) => _stopRecording(cameraService),
                            onTapCancel: () => _stopRecording(cameraService),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (cameraService?.isRecording == true) ? Colors.red : Colors.white,
                                  shape: (cameraService?.isRecording == true) ? BoxShape.rectangle : BoxShape.circle,
                                  borderRadius: (cameraService?.isRecording == true) ? BorderRadius.circular(8) : null,
                                ),
                              ),
                            ),
                          ),

                          // Upload/Next button (only show when content is ready)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: (_lastGifResult != null) 
                                  ? Colors.purple 
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: (_lastGifResult != null) 
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: IconButton(
                              icon: Icon(
                                (_lastGifResult != null) ? Icons.publish : Icons.arrow_forward,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: (_lastGifResult != null) ? _proceedToEdit : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCameraPreview(CameraService? cameraService) {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (cameraService == null || !cameraService.isInitialized) {
      return _buildLoadingState();
    }

    return ClipRect(
      child: Transform.scale(
        scale: 1.0,
        child: Center(
          child: cameraService.cameraPreview,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF11998E),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF11998E),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () => _applyEffect(label),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double progress) {
    final seconds = (progress * 6).round(); // 6 second max
    return '00:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording(CameraService? cameraService) async {
    if (cameraService == null || !cameraService.isInitialized) return;

    try {
      await cameraService.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording(CameraService? cameraService) async {
    if (cameraService == null || !cameraService.isRecording) return;

    try {
      final result = await cameraService.stopRecording();
      
      if (mounted && result.hasFrames) {
        // Store recording result for publishing
        _lastRecordingResult = result;
        
        // Convert frames to GIF
        await _convertFramesToGif(result);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded ${result.frameCount} frames using ${result.selectedApproach}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  Future<void> _convertFramesToGif(VineRecordingResult recordingResult) async {
    try {
      // Show processing state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Creating GIF...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Convert frames to GIF
      final gifResult = await _gifService.createGifFromFrames(
        frames: recordingResult.frames,
        originalWidth: 640, // Assuming camera resolution - could be dynamic
        originalHeight: 480,
        quality: GifQuality.medium,
      );

      if (mounted) {
        setState(() {
          _lastGifResult = gifResult;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'GIF created! ${gifResult.frameCount} frames, ${gifResult.fileSizeMB.toStringAsFixed(2)}MB',
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Preview',
              onPressed: () => _showGifPreview(gifResult),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create GIF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGifPreview(GifResult gifResult) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GIF Preview
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _lastGifResult?.gifBytes != null
                      ? Image.memory(
                          _lastGifResult!.gifBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gif_box,
                                size: 64,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'GIF Preview',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '(Loading...)',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // GIF Stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Frames:', style: TextStyle(color: Colors.white70)),
                        Text('${gifResult.frameCount}', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Size:', style: TextStyle(color: Colors.white70)),
                        Text('${gifResult.fileSizeMB.toStringAsFixed(2)} MB', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Quality:', style: TextStyle(color: Colors.white70)),
                        Text('${gifResult.quality.name}', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Compression:', style: TextStyle(color: Colors.white70)),
                        Text('${(gifResult.compressionRatio * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _publishToNostr();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      child: const Text('Share to Nostr'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGifDetails(GifResult gifResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GIF Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frames: ${gifResult.frameCount}'),
            Text('Dimensions: ${gifResult.width}x${gifResult.height}'),
            Text('File Size: ${gifResult.fileSizeMB.toStringAsFixed(2)} MB'),
            Text('Quality: ${gifResult.quality.name}'),
            Text('Processing Time: ${gifResult.processingTime.inMilliseconds}ms'),
            Text('Compression: ${(gifResult.compressionRatio * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openGallery() {
    // TODO: Implement gallery/library functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening gallery...')),
    );
  }

  void _applyEffect(String effect) {
    // TODO: Implement effects functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied $effect effect')),
    );
  }

  void _proceedToEdit() {
    if (_lastGifResult == null) return;
    
    // Show dialog to get caption and publish to Nostr
    _showPublishDialog();
  }

  void _showPublishDialog() {
    final TextEditingController captionController = TextEditingController();
    final TextEditingController hashtagsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish to Nostr'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'What\'s happening?',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hashtagsController,
              decoration: const InputDecoration(
                labelText: 'Hashtags',
                hintText: 'vine,nostr,gif (comma separated)',
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 16),
            if (_lastGifResult != null)
              Text(
                'GIF: ${_lastGifResult!.frameCount} frames, ${_lastGifResult!.fileSizeMB.toStringAsFixed(2)}MB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final caption = captionController.text.trim();
              final hashtagsText = hashtagsController.text.trim();
              final hashtags = hashtagsText.isNotEmpty 
                  ? hashtagsText.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty).toList()
                  : <String>[];
              
              _publishToNostr(caption: caption, hashtags: hashtags);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishToNostr({String? caption, List<String>? hashtags}) async {
    if (_lastRecordingResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recording to publish'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Use provided values or defaults
    final publishCaption = caption ?? 'Check out my NostrVine!';
    final publishHashtags = hashtags ?? ['nostrvine', 'vine', 'nostr'];

    // Show publishing progress
    _showPublishingProgress();

    try {
      if (_publishingService == null) {
        throw Exception('Publishing service not initialized');
      }
      
      final result = await _publishingService!.publishVineLocal(
        recordingResult: _lastRecordingResult!,
        caption: publishCaption,
        hashtags: publishHashtags,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.retryCount > 0 
                  ? '🎉 Vine published successfully after ${result.retryCount} retries!'
                  : '🎉 Vine published to Nostr successfully!'
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (result.isOfflineQueued) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📱 Vine queued for publishing when connection is restored'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'View Queue',
                textColor: Colors.white,
                onPressed: _showOfflineQueueDialog,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.retryCount > 0
                  ? 'Failed to publish after ${result.retryCount} retries: ${result.error}'
                  : 'Failed to publish: ${result.error}'
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: result.retryCount < 3
                ? SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () => _publishToNostr(caption: publishCaption, hashtags: publishHashtags),
                  )
                : null,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publishing failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showPublishingProgress() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_publishingService != null)
                ListenableBuilder(
                  listenable: _publishingService!,
                  builder: (context, _) {
                    return Column(
                      children: [
                        CircularProgressIndicator(
                          value: _publishingService!.progress,
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _publishingService!.statusMessage ?? 'Publishing...',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_publishingService!.progress * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                )
              else
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing...'),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimerText(CameraService? cameraService) {
    if (cameraService == null || !cameraService.isRecording) {
      return '6s';
    }
    
    // Calculate remaining time (6 seconds total)
    const totalSeconds = 6;
    final progress = cameraService.recordingProgress;
    final remainingSeconds = totalSeconds - (totalSeconds * progress).round();
    
    return '${remainingSeconds}s';
  }
  
  void _showOfflineQueueDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Offline Queue'),
            const Spacer(),
            if ((_publishingService?.offlineQueueCount ?? 0) > 0)
              Chip(
                label: Text('${_publishingService?.offlineQueueCount ?? 0}'),
                backgroundColor: Colors.orange.withOpacity(0.2),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((_publishingService?.offlineQueueCount ?? 0) == 0)
                const Text('No content waiting to be published.')
              else ...[
                Text(
                  'You have ${_publishingService?.offlineQueueCount ?? 0} vine(s) waiting to be published when your connection is restored.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                // Connection status
                FutureBuilder<bool>(
                  future: _checkConnectionStatus(),
                  builder: (context, snapshot) {
                    final isConnected = snapshot.data ?? false;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isConnected ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isConnected ? Icons.wifi : Icons.wifi_off,
                            color: isConnected ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'Connected' : 'No connection',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          if ((_publishingService?.offlineQueueCount ?? 0) > 0) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showClearQueueConfirmation();
              },
              child: const Text('Clear Queue'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryOfflineQueue();
              },
              child: const Text('Retry Now'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Future<bool> _checkConnectionStatus() async {
    try {
      final result = await InternetAddress.lookup('relay.damus.io');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  void _showClearQueueConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Offline Queue'),
        content: Text(
          'Are you sure you want to clear all ${_publishingService?.offlineQueueCount ?? 0} queued vine(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearOfflineQueue();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _clearOfflineQueue() async {
    await _publishingService?.clearOfflineQueue();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Offline queue cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  Future<void> _retryOfflineQueue() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Retrying offline queue...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    try {
      await _publishingService?.retryOfflineQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Offline queue processing completed'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to process offline queue: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}