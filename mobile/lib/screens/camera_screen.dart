import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/camera_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/vine_publishing_service.dart';
import '../services/content_moderation_service.dart';
import '../services/content_reporting_service.dart';
import '../services/upload_manager.dart';
import '../models/pending_upload.dart';
import '../widgets/upload_progress_indicator.dart';
import 'camera_settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraService? _cameraService;
  late final INostrService _nostrService;
  VinePublishingService? _publishingService;
  ContentModerationService? _moderationService;
  ContentReportingService? _reportingService;
  UploadManager? _uploadManager;
  String? _errorMessage;
  VineRecordingResult? _lastRecordingResult;
  PendingUpload? _currentUpload;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _cameraService?.dispose();
    // DO NOT dispose _nostrService - it's managed by Provider and shared across screens
    // DO NOT dispose _publishingService - it's managed by Provider and shared across screens
    _moderationService?.dispose();
    _reportingService?.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // Get services from providers
    _nostrService = context.read<INostrService>();
    _publishingService = context.read<VinePublishingService>();
    _uploadManager = context.read<UploadManager>();
    
    // Initialize content moderation services
    try {
      final prefs = await SharedPreferences.getInstance();
      _moderationService = ContentModerationService(
        prefs: prefs,
      );
      _reportingService = ContentReportingService(
        nostrService: _nostrService,
        prefs: prefs,
      );
      
      await _moderationService!.initialize();
      await _reportingService!.initialize();
      debugPrint('✅ Content moderation services initialized');
    } catch (e) {
      debugPrint('⚠️ Content moderation initialization failed: $e');
      // Continue anyway - moderation is optional
    }
    
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _cameraService ?? ChangeNotifier(),
        builder: (context, _) {
          final cameraService = _cameraService;
            // Handle null camera service
            if (cameraService == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            }
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
                      // Remove the X button that was causing navigation issues
                      const SizedBox(width: 48), // Maintain spacing
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
                                  color: Colors.orange.withValues(alpha: 0.8),
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
                              color: Colors.black.withValues(alpha: 0.5),
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
                        onPressed: () => cameraService.switchCamera(),
                      ),
                    ],
                  ),
                ),

                // Recording progress bar or instruction
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 20,
                  right: 20,
                  child: () {
                    final isRecording = cameraService.isRecording == true;
                    debugPrint('🔍 UI Update: isRecording=$isRecording, progress=${cameraService.recordingProgress}');
                    return isRecording
                      ? Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: cameraService.recordingProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Tap to start recording • Tap again to stop',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                  }(),
                ),

                // Settings button only
                Positioned(
                  right: 20,
                  top: MediaQuery.of(context).size.height * 0.3,
                  child: _buildSettingsButton(),
                ),

                // Recording state indicator (only show during manual processing, not auto-stop)
                if (cameraService.state == RecordingState.processing && !cameraService.isRecording)
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

                // Upload progress indicator
                if (_currentUpload != null)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 120,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: CompactUploadProgress(
                        upload: _currentUpload!,
                        onTap: _showUploadProgress,
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
                      if (cameraService.isRecording == true)
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
                                'REC ${_formatDuration(cameraService.recordingProgress)}',
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
                                color: Colors.white.withValues(alpha: 0.2),
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

                          // Record button - tap to start/stop
                          GestureDetector(
                            onTap: () {
                              if (cameraService.isRecording == true) {
                                _stopRecording(cameraService);
                              } else {
                                _startRecording(cameraService);
                              }
                            },
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
                                  color: (cameraService.isRecording == true) ? Colors.red : Colors.white,
                                  shape: (cameraService.isRecording == true) ? BoxShape.rectangle : BoxShape.circle,
                                  borderRadius: (cameraService.isRecording == true) ? BorderRadius.circular(8) : null,
                                ),
                              ),
                            ),
                          ),

                          // Upload/Next button (only show when content is ready)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: (_currentUpload != null) 
                                  ? Colors.purple 
                                  : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: (_currentUpload != null) 
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: IconButton(
                              icon: Icon(
                                (_currentUpload != null) ? Icons.cloud_upload : Icons.arrow_forward,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: (_currentUpload != null) ? _showUploadProgress : null,
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


  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: () => _openSettings(),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.pink.withValues(alpha: 0.5), width: 1),
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.pink,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.pink,
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

  bool _isStartingRecording = false;
  
  Future<void> _startRecording(CameraService? cameraService) async {
    if (cameraService == null || !cameraService.isInitialized || _isStartingRecording || cameraService.isRecording) {
      debugPrint('⚠️ Ignoring start recording request - isStarting: $_isStartingRecording, isRecording: ${cameraService?.isRecording}');
      return;
    }

    _isStartingRecording = true;
    try {
      debugPrint('🎬 UI: Starting recording...');
      await cameraService.startRecording();
      debugPrint('✅ UI: Recording started successfully');
    } catch (e) {
      debugPrint('❌ UI: Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    } finally {
      _isStartingRecording = false;
    }
  }

  bool _isStoppingRecording = false;
  
  Future<void> _stopRecording(CameraService? cameraService) async {
    if (cameraService == null || !cameraService.isRecording || _isStoppingRecording) {
      debugPrint('⚠️ Ignoring stop recording request - isRecording: ${cameraService?.isRecording}, isStopping: $_isStoppingRecording');
      return;
    }

    _isStoppingRecording = true;
    try {
      debugPrint('🛑 UI: Stopping recording...');
      final result = await cameraService.stopRecording();
      debugPrint('✅ UI: Recording stopped successfully');
      
      if (mounted && result.hasFrames) {
        // Store recording result for publishing
        _lastRecordingResult = result;
        
        // Start Cloudinary upload
        await _startCloudinaryUpload(result);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recorded ${result.frameCount} frames using ${result.selectedApproach}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ UI: Failed to stop recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    } finally {
      _isStoppingRecording = false;
    }
  }

  Future<void> _startCloudinaryUpload(VineRecordingResult recordingResult) async {
    try {
      if (_uploadManager == null) {
        throw Exception('Upload manager not initialized');
      }

      // First, save the video frames to a temporary file
      // TODO: For now, we'll create a placeholder file - this should be replaced with actual video creation from frames
      final tempVideoFile = await _createVideoFromFrames(recordingResult);
      
      // Get user's public key (for now using a placeholder)
      final userPubkey = 'placeholder-pubkey'; // TODO: Get from user profile service
      
      // Start the upload
      final upload = await _uploadManager!.startUpload(
        videoFile: tempVideoFile,
        nostrPubkey: userPubkey,
        title: 'Vine Video', // TODO: Allow user to set title
        description: 'Created with NostrVine', // TODO: Allow user to set description
        hashtags: ['nostrvine', 'vine'], // TODO: Allow user to set hashtags
      );
      
      setState(() {
        _currentUpload = upload;
        _errorMessage = null;
      });

      debugPrint('✅ Upload started successfully: ${upload.id}');
      debugPrint('📄 Video file: ${tempVideoFile.path}');
      debugPrint('🎬 Frame count: ${recordingResult.frames.length}');
      debugPrint('⏱️ Processing time: ${recordingResult.processingTime.inMilliseconds}ms');
      debugPrint('🎯 Selected approach: ${recordingResult.selectedApproach}');
      
      if (mounted) {
        setState(() {}); // Trigger UI update to show upload progress
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vine recorded! Uploading to cloud for processing...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to start upload: $e');
      setState(() {
        _errorMessage = 'Failed to start upload: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Create a temporary video file from frames (placeholder implementation)
  Future<File> _createVideoFromFrames(VineRecordingResult recordingResult) async {
    // TODO: Implement proper video creation from frames using FFmpeg
    // For now, create a placeholder file
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/nostrvine_${DateTime.now().millisecondsSinceEpoch}.mp4');
    
    // Write a minimal MP4 header as placeholder
    await tempFile.writeAsBytes([0x00, 0x00, 0x00, 0x20]); // Placeholder
    
    debugPrint('⚠️ TODO: Replace placeholder video creation with real frame-to-video conversion');
    
    return tempFile;
  }



  void _openGallery() {
    // TODO: Implement gallery/library functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening gallery...')),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: _cameraService,
          child: const CameraSettingsScreen(),
        ),
      ),
    );
  }


  void _showUploadProgress() {
    if (_currentUpload == null) return;
    
    // Show upload progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upload Progress'),
        content: SizedBox(
          width: 300,
          child: UploadProgressIndicator(
            upload: _currentUpload!,
            onRetry: () async {
              Navigator.of(context).pop();
              if (_uploadManager != null && _currentUpload != null) {
                await _uploadManager!.retryUpload(_currentUpload!.id);
              }
            },
            onCancel: () async {
              Navigator.of(context).pop();
              if (_uploadManager != null && _currentUpload != null) {
                await _uploadManager!.cancelUpload(_currentUpload!.id);
                setState(() {
                  _currentUpload = null;
                });
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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
    
    // Debug log every few frames to avoid spam
    if (remainingSeconds % 2 == 0) {
      debugPrint('🕐 Timer update: progress=${(progress * 100).toStringAsFixed(1)}%, remaining=${remainingSeconds}s');
    }
    
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
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
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
                        color: isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
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