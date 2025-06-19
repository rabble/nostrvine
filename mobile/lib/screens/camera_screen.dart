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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing camera icon with shimmer effect
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 60,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                );
              },
              onEnd: () {
                // Restart animation
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 32),
            
            // Skeleton loading bars with shimmer
            Column(
              children: [
                _buildSkeletonBar(width: 200, height: 20),
                const SizedBox(height: 12),
                _buildSkeletonBar(width: 160, height: 16),
                const SizedBox(height: 8),
                _buildSkeletonBar(width: 120, height: 16),
              ],
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Preparing your camera...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment on first launch',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBar({required double width, required double height}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (2.0 * value), 0.0),
              end: Alignment(1.0 + (2.0 * value), 0.0),
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.1),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildErrorState(String error) {
    // Determine error type and customize UI accordingly
    final isPermissionError = error.toLowerCase().contains('permission');
    final isNetworkError = error.toLowerCase().contains('network') || 
                          error.toLowerCase().contains('connection');
    final isCameraUnavailable = error.toLowerCase().contains('camera') && 
                              error.toLowerCase().contains('not available');

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error-specific icon and color
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getErrorColor(isPermissionError, isNetworkError, isCameraUnavailable)
                      .withValues(alpha: 0.1),
                  border: Border.all(
                    color: _getErrorColor(isPermissionError, isNetworkError, isCameraUnavailable)
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getErrorIcon(isPermissionError, isNetworkError, isCameraUnavailable),
                  size: 60,
                  color: _getErrorColor(isPermissionError, isNetworkError, isCameraUnavailable),
                ),
              ),
              const SizedBox(height: 24),
              
              // Error title
              Text(
                _getErrorTitle(isPermissionError, isNetworkError, isCameraUnavailable),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // User-friendly error description
              Text(
                _getErrorDescription(isPermissionError, isNetworkError, isCameraUnavailable, error),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Technical details (collapsible)
              if (!isPermissionError && !isNetworkError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Technical Details',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Action buttons
              Column(
                children: [
                  // Primary action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleErrorAction(isPermissionError, isNetworkError),
                      icon: Icon(_getActionIcon(isPermissionError, isNetworkError)),
                      label: Text(_getActionText(isPermissionError, isNetworkError)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getErrorColor(isPermissionError, isNetworkError, isCameraUnavailable),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Secondary action
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _initializeCamera,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Color _getErrorColor(bool isPermissionError, bool isNetworkError, bool isCameraUnavailable) {
    if (isPermissionError) return Colors.orange;
    if (isNetworkError) return Colors.blue;
    if (isCameraUnavailable) return Colors.red;
    return Colors.amber;
  }

  IconData _getErrorIcon(bool isPermissionError, bool isNetworkError, bool isCameraUnavailable) {
    if (isPermissionError) return Icons.security;
    if (isNetworkError) return Icons.wifi_off;
    if (isCameraUnavailable) return Icons.camera_alt_outlined;
    return Icons.error_outline;
  }

  String _getErrorTitle(bool isPermissionError, bool isNetworkError, bool isCameraUnavailable) {
    if (isPermissionError) return 'Camera Permission Required';
    if (isNetworkError) return 'Network Connection Issue';
    if (isCameraUnavailable) return 'Camera Not Available';
    return 'Camera Error';
  }

  String _getErrorDescription(bool isPermissionError, bool isNetworkError, bool isCameraUnavailable, String originalError) {
    if (isPermissionError) {
      return 'NostrVine needs camera access to record videos. Please allow camera permissions in your device settings.';
    }
    if (isNetworkError) {
      return 'Unable to connect to video processing services. Please check your internet connection and try again.';
    }
    if (isCameraUnavailable) {
      return 'Your device camera is currently unavailable. This could be because another app is using it or there\'s a hardware issue.';
    }
    return 'Something went wrong while setting up your camera. This is usually temporary and can be fixed by trying again.';
  }

  IconData _getActionIcon(bool isPermissionError, bool isNetworkError) {
    if (isPermissionError) return Icons.settings;
    if (isNetworkError) return Icons.wifi;
    return Icons.camera_alt;
  }

  String _getActionText(bool isPermissionError, bool isNetworkError) {
    if (isPermissionError) return 'Open Settings';
    if (isNetworkError) return 'Check Connection';
    return 'Retry Camera';
  }

  void _handleErrorAction(bool isPermissionError, bool isNetworkError) {
    if (isPermissionError) {
      _openAppSettings();
    } else if (isNetworkError) {
      _checkNetworkAndRetry();
    } else {
      _initializeCamera();
    }
  }

  void _openAppSettings() {
    // TODO: Open app settings using url_launcher or app_settings package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please enable camera permissions in your device settings'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () {
            // Implementation would go here
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _checkNetworkAndRetry() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking network connection...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Check network connectivity
    final hasConnection = await _checkConnectionStatus();
    
    if (hasConnection) {
      _initializeCamera();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection detected. Please check your network settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
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
            onDelete: () async {
              Navigator.of(context).pop();
              if (_uploadManager != null && _currentUpload != null) {
                await _uploadManager!.deleteUpload(_currentUpload!.id);
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