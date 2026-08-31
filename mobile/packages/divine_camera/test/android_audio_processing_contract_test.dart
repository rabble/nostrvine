// ABOUTME: Static guards for the Android unprocessed-audio capture contract.
// ABOUTME: Pins that Music mode reaches the recording audio source (#8079).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readNativeSource(String fileName) {
  const packagePath = 'android/src/main/kotlin/co/openvine/divine_camera';
  final file = [
    File('$packagePath/$fileName'),
    File('packages/divine_camera/$packagePath/$fileName'),
  ].firstWhere((file) => file.existsSync());

  return file.readAsStringSync();
}

/// Returns the Kotlin declaration starting at [signature] up to its closing
/// brace, so an assertion cannot match an identical line elsewhere in the
/// file, nor a line that sits outside the scope being asserted on.
String _declarationAt(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('No declaration starting with "$signature".');
  }

  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces after "$signature".');
}

void main() {
  group('Android unprocessed audio contract', () {
    late final String pluginSource;
    late final String controllerSource;
    late final String resolveAudioSource;

    setUpAll(() {
      pluginSource = _readNativeSource('DivineCameraPlugin.kt');
      controllerSource = _readNativeSource('CameraController.kt');
      resolveAudioSource = _declarationAt(
        controllerSource,
        'private fun resolveAudioSource(',
      );
    });

    test('the plugin reads the Music mode argument off the channel', () {
      // The defect this closes: five of the six initialize arguments were
      // read and this one was dropped by MethodCall.argument without an
      // error, so the setting could not reach Android at all.
      expect(
        pluginSource,
        contains(
          'call.argument<Boolean>("preferUnprocessedAudio") ?: false',
        ),
      );
    });

    test('the plugin forwards it to the controller', () {
      expect(
        _declarationAt(pluginSource, 'private fun initializeCamera('),
        contains('enableAutoLensSwitch, preferUnprocessedAudio)'),
      );
    });

    test('the controller keeps it for the life of the session', () {
      // Stored per initialize like every other session flag, because the
      // Recorder that consumes it is built later, on bind and on lens switch.
      expect(
        controllerSource,
        contains('private var prefersUnprocessedAudio: Boolean = false'),
      );
      expect(
        _declarationAt(controllerSource, '    fun initialize('),
        contains('this.prefersUnprocessedAudio = preferUnprocessedAudio'),
      );
    });

    test('resolving a source consults the preference', () {
      expect(
        resolveAudioSource,
        contains('preferUnprocessedAudio = prefersUnprocessedAudio'),
      );
    });

    test('unprocessed support is probed, and only "true" counts', () {
      // The CDD tells an unsupporting device to return null while AOSP
      // returns "false", so the check has to reject both rather than test
      // for null. toBoolean() is what makes an unexpected value read as
      // unsupported instead of silently claiming support.
      expect(
        resolveAudioSource,
        contains('AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED'),
      );
      expect(resolveAudioSource, contains('.toBoolean()'));
    });

    test('the resolved source is named in the diagnostic', () {
      // A "Music mode did nothing" report is only actionable if the log says
      // which source was chosen and whether the device claimed support.
      expect(resolveAudioSource, contains(r'${audioSourceName(source)}'));
      expect(
        resolveAudioSource,
        contains(r'music mode: $prefersUnprocessedAudio'),
      );
      expect(
        resolveAudioSource,
        contains(r'unprocessed supported: $unprocessedSupported'),
      );
    });
  });
}
