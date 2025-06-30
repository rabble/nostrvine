// ABOUTME: Web implementation of cryptography_flutter plugin for Flutter web compatibility
// ABOUTME: Provides fallback implementations that avoid Platform._version calls

import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';

/// Web implementation of CryptographyFlutterPlugin
class CryptographyFlutterPlugin {
  /// Registers the web plugin
  static void registerWith(Registrar registrar) {
    // No-op for web
  }
}