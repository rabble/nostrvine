// ABOUTME: Universal camera screen that works on all platforms (mobile, macOS, web, Windows)
// ABOUTME: Uses VineRecordingController abstraction for consistent recording experience

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vine_recording_controller.dart';
import '../services/nostr_key_manager.dart';
import '../services/upload_manager.dart';
import '../services/video_manager_interface.dart';
import '../models/pending_upload.dart';
import '../widgets/vine_recording_controls.dart';
import '../theme/vine_theme.dart';
import 'video_metadata_screen.dart';
import '../main.dart';

class UniversalCameraScreen extends StatefulWidget {
  const UniversalCameraScreen({super.key});

  @override
  State<UniversalCameraScreen> createState() => _UniversalCameraScreenState();
}

class _UniversalCameraScreenState extends State<UniversalCameraScreen> {
  late VineRecordingController _recordingController;
  late final NostrKeyManager _keyManager;
  UploadManager? _uploadManager;
  
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _recordingController = VineRecordingController();
    _initializeServices();
  }

  @override
  void dispose() {
    _recordingController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // Stop all background videos immediately when camera screen opens
      final videoManager = context.read<IVideoManager>();
      videoManager.stopAllVideos();
      debugPrint('🎥 Stopped all background videos on camera screen init');
      
      // Get services from providers
      _uploadManager = context.read<UploadManager>();
      _keyManager = context.read<NostrKeyManager>();
      
      // Initialize recording controller
      await _recordingController.initialize();
      
      setState(() {
        _errorMessage = null;
      });
      
      // For macOS, give the camera widget time to mount and initialize
      if (Theme.of(context).platform == TargetPlatform.macOS) {
        debugPrint('📷 Waiting for macOS camera widget to mount...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('📷 macOS camera widget should now be mounted');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
      debugPrint('❌ Camera initialization failed: $e');
    }
  }

  Future<void> _onRecordingComplete() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Finish recording and get the video file
      final videoFile = await _recordingController.finishRecording();
      
      if (videoFile != null && mounted) {
        // Navigate to metadata screen
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreen(
              videoFile: videoFile,
              duration: _recordingController.totalRecordedDuration,
            ),
          ),
        );

        if (result != null && mounted) {
          // Get current user's pubkey
          final pubkey = _keyManager.publicKey ?? '';
          
          // Start upload through upload manager
          final upload = await _uploadManager!.startUpload(
            videoFile: videoFile,
            nostrPubkey: pubkey,
            title: result['caption'] ?? '',
            description: result['caption'] ?? '',
            hashtags: result['hashtags'] ?? [],
          );

          // Don't reset here - let files persist until next recording session
          
          // Navigate back to the main feed immediately after starting upload
          // The upload will continue in the background
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainNavigationScreen(initialTabIndex: 0),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing recording: $e');
      
      // Don't reset here on error - let files persist until next recording session
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process recording: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onCancel() {
    // Just navigate back - keep recordings for potential retry
    Navigator.of(context).pop();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Record Vine'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Camera preview (full screen)
          if (_errorMessage == null)
            Positioned.fill(
              child: Builder(
                builder: (context) {
                  debugPrint('📷 Building camera preview widget');
                  return _recordingController.cameraPreview;
                },
              ),
            )
          else
            _buildErrorView(),
          
          // Recording UI overlay
          if (_errorMessage == null)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _recordingController,
                builder: (context, child) {
                  return VineRecordingUI(
                    controller: _recordingController,
                    onRecordingComplete: _onRecordingComplete,
                    onCancel: _onCancel,
                  );
                },
              ),
            ),
          
          // Upload progress indicator removed - we navigate away immediately after upload starts
          
          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(VineTheme.vineGreen),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing your vine...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Error',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _initializeServices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}