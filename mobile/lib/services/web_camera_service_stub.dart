// ABOUTME: Stub implementation for web camera service when not running on web platform
// ABOUTME: Prevents import errors on non-web platforms while allowing conditional imports

import 'package:flutter/material.dart';

/// Stub for WebCameraService on non-web platforms
class WebCameraService {
  Future<void> initialize() async {
    throw UnsupportedError('WebCameraService is only supported on web platform');
  }
  
  Future<void> startRecording() async {
    throw UnsupportedError('WebCameraService is only supported on web platform');
  }
  
  Future<String?> stopRecording() async {
    throw UnsupportedError('WebCameraService is only supported on web platform');
  }
  
  void dispose() {}
  
  static void revokeBlobUrl(String blobUrl) {
    // No-op on non-web platforms
  }
}

/// Stub for WebCameraPreview on non-web platforms
class WebCameraPreview extends StatelessWidget {
  final dynamic cameraService;
  
  const WebCameraPreview({
    super.key,
    required this.cameraService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Web camera not available on this platform',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}