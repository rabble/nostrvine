// ABOUTME: Camera screen router that directs to appropriate camera implementation
// ABOUTME: Uses UniversalCameraScreen for all supported platforms, placeholder for unsupported

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'web_camera_placeholder.dart';
import 'universal_camera_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use universal camera screen for all supported platforms
    // This includes mobile (iOS/Android), macOS, web, and Windows
    if (_isSupportedPlatform()) {
      return const UniversalCameraScreen();
    }
    
    // Show placeholder only for unsupported platforms and simulators
    return const WebCameraPlaceholder();
  }
  
  bool _isSupportedPlatform() {
    // Web is supported (will use getUserMedia)
    if (kIsWeb) return true;
    
    // All desktop platforms are supported
    if (Platform.isMacOS || Platform.isWindows) return true;
    
    // Mobile platforms are supported (but not simulators in development)
    if (Platform.isIOS || Platform.isAndroid) return true;
    
    // Linux not yet supported
    return false;
  }
}