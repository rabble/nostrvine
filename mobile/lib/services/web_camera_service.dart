// ABOUTME: Web-specific camera service using getUserMedia and MediaRecorder APIs
// ABOUTME: Provides native web camera integration for Vine recording in browsers

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter  
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web camera service that uses getUserMedia and MediaRecorder
class WebCameraService {
  html.MediaStream? _mediaStream;
  html.MediaRecorder? _mediaRecorder;
  html.VideoElement? _videoElement;
  final List<html.Blob> _recordedChunks = [];
  bool _isRecording = false;
  bool _isInitialized = false;
  StreamController<String>? _recordingCompleteController;

  /// Initialize the web camera
  Future<void> initialize() async {
    if (!kIsWeb) {
      throw Exception('WebCameraService can only be used on web platforms');
    }

    try {
      // Request camera permissions and get media stream
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 640},
          'facingMode': 'user', // Front camera by default for web
        },
        'audio': true,
      });

      // Create video element for preview
      _videoElement = html.VideoElement()
        ..srcObject = _mediaStream
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _isInitialized = true;
      debugPrint('📷 Web camera initialized successfully');
    } catch (e) {
      debugPrint('❌ Web camera initialization failed: $e');
      throw Exception('Failed to initialize web camera: $e');
    }
  }

  /// Start recording a segment
  Future<void> startRecording() async {
    debugPrint('📹 WebCameraService.startRecording() - initialized: $_isInitialized, hasStream: ${_mediaStream != null}, isRecording: $_isRecording');
    
    if (!_isInitialized || _mediaStream == null || _isRecording) {
      final error = 'Camera not initialized or already recording - initialized: $_isInitialized, hasStream: ${_mediaStream != null}, isRecording: $_isRecording';
      debugPrint('❌ WebCameraService.startRecording() failed: $error');
      throw Exception(error);
    }

    try {
      _recordedChunks.clear();
      _recordingCompleteController = StreamController<String>();

      // Create MediaRecorder
      _mediaRecorder = html.MediaRecorder(_mediaStream!, {
        'mimeType': _getSupportedMimeType(),
      });

      // Set up event listeners
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _recordedChunks.add(blobEvent.data!);
        }
      });

      _mediaRecorder!.addEventListener('stop', (html.Event event) {
        _finishRecording();
      });

      _mediaRecorder!.addEventListener('error', (html.Event event) {
        debugPrint('❌ MediaRecorder error: $event');
        _isRecording = false;
      });

      // Start recording
      _mediaRecorder!.start();
      _isRecording = true;
      
      debugPrint('🎬 Started web camera recording');
    } catch (e) {
      _isRecording = false;
      debugPrint('❌ Failed to start web recording: $e');
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop recording and return the blob URL
  Future<String> stopRecording() async {
    debugPrint('📹 WebCameraService.stopRecording() - isRecording: $_isRecording, hasRecorder: ${_mediaRecorder != null}');
    
    if (!_isRecording || _mediaRecorder == null) {
      final error = 'Not currently recording - isRecording: $_isRecording, hasRecorder: ${_mediaRecorder != null}';
      debugPrint('❌ WebCameraService.stopRecording() failed: $error');
      throw Exception(error);
    }

    try {
      _mediaRecorder!.stop();
      _isRecording = false;
      
      // Wait for the recording to be processed
      final blobUrl = await _recordingCompleteController!.stream.first;
      return blobUrl;
    } catch (e) {
      debugPrint('❌ Failed to stop web recording: $e');
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Finish recording and create blob URL
  void _finishRecording() {
    if (_recordedChunks.isEmpty) {
      _recordingCompleteController?.addError('No recorded data');
      return;
    }

    try {
      // Create blob from recorded chunks
      final blob = html.Blob(_recordedChunks, _getSupportedMimeType());
      final blobUrl = html.Url.createObjectUrl(blob);
      
      _recordingCompleteController?.add(blobUrl);
      debugPrint('✅ Web recording completed, blob URL: $blobUrl');
    } catch (e) {
      _recordingCompleteController?.addError(e);
      debugPrint('❌ Failed to create blob: $e');
    }
  }

  /// Get the video element for preview
  html.VideoElement? get videoElement => _videoElement;

  /// Check if camera is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Switch between front and back camera (if available)
  Future<void> switchCamera() async {
    if (!_isInitialized) return;

    try {
      // Stop current stream
      _mediaStream?.getTracks().forEach((track) => track.stop());

      // Get current facing mode
      final currentConstraints = _mediaStream?.getVideoTracks().first.getSettings();
      final currentFacingMode = currentConstraints?['facingMode'] ?? 'user';
      final newFacingMode = currentFacingMode == 'user' ? 'environment' : 'user';

      // Request new stream with different camera
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 640},
          'facingMode': newFacingMode,
        },
        'audio': true,
      });

      // Update video element
      _videoElement?.srcObject = _mediaStream;
      
      debugPrint('🔄 Switched to $newFacingMode camera');
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
      // If switching fails, try to restore original stream
      try {
        _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
          'video': {
            'width': {'ideal': 640},
            'height': {'ideal': 640},
            'facingMode': 'user',
          },
          'audio': true,
        });
        _videoElement?.srcObject = _mediaStream;
      } catch (restoreError) {
        debugPrint('❌ Failed to restore camera: $restoreError');
      }
    }
  }

  /// Get supported MIME type for recording
  String _getSupportedMimeType() {
    // Try different MIME types in order of preference
    final mimeTypes = [
      'video/webm;codecs=vp9',
      'video/webm;codecs=vp8',
      'video/webm',
      'video/mp4',
    ];

    for (final mimeType in mimeTypes) {
      if (html.MediaRecorder.isTypeSupported(mimeType)) {
        return mimeType;
      }
    }

    // Fallback to webm if nothing else is supported
    return 'video/webm';
  }

  /// Download recorded video as file
  void downloadRecording(String blobUrl, String filename) {
    final anchor = html.AnchorElement(href: blobUrl)
      ..download = filename
      ..style.display = 'none';
    
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    
    debugPrint('📥 Download triggered for $filename');
  }

  /// Revoke blob URL to free memory
  static void revokeBlobUrl(String blobUrl) {
    if (blobUrl.startsWith('blob:')) {
      try {
        html.Url.revokeObjectUrl(blobUrl);
        debugPrint('🧹 Revoked blob URL: $blobUrl');
      } catch (e) {
        debugPrint('⚠️ Error revoking blob URL: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaRecorder = null;
    _videoElement = null;
    _recordingCompleteController?.close();
    _isInitialized = false;
    debugPrint('🗑️ Web camera service disposed');
  }
}

/// Flutter widget that wraps the HTML video element for web camera preview
class WebCameraPreview extends StatefulWidget {
  final WebCameraService cameraService;
  
  const WebCameraPreview({
    super.key,
    required this.cameraService,
  });

  @override
  State<WebCameraPreview> createState() => _WebCameraPreviewState();
}

class _WebCameraPreviewState extends State<WebCameraPreview> {
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _registerVideoElement();
  }

  void _registerVideoElement() {
    if (!kIsWeb || widget.cameraService.videoElement == null) return;

    // Generate unique view type
    _viewType = 'web-camera-${DateTime.now().millisecondsSinceEpoch}';

    // Register the video element as a platform view
    // ignore: avoid_web_libraries_in_flutter
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => widget.cameraService.videoElement!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _viewType == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType!);
  }
}

/// Convert blob URL to Uint8List for further processing
Future<Uint8List> blobUrlToBytes(String blobUrl) async {
  final response = await html.window.fetch(blobUrl);
  final blob = await response.blob();
  final reader = html.FileReader();
  
  final completer = Completer<Uint8List>();
  reader.onLoadEnd.listen((_) {
    final result = reader.result as List<int>;
    completer.complete(Uint8List.fromList(result));
  });
  
  reader.onError.listen((error) {
    completer.completeError('Failed to read blob: $error');
  });
  
  reader.readAsArrayBuffer(blob);
  return completer.future;
}