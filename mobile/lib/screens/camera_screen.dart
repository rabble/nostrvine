import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../services/gif_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraService? _cameraService;
  final GifService _gifService = GifService();
  String? _errorMessage;
  GifResult? _lastGifResult;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraService?.dispose();
    super.dispose();
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '6s',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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

                // Recording state indicator
                if (cameraService?.state == RecordingState.processing)
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
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_forward,
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
          child: CameraPreview(cameraService.controller!),
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
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () => _showGifDetails(gifResult),
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
    
    // TODO: Navigate to editing/posting screen with GIF data
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ready to share: ${_lastGifResult!.frameCount} frame GIF (${_lastGifResult!.fileSizeMB.toStringAsFixed(2)}MB)',
        ),
      ),
    );
  }
}