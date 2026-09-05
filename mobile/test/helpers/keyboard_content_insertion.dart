// ABOUTME: Test helper for simulating keyboard rich-content insertion
// ABOUTME: Sends the same commitContent platform message used by Android IMEs

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates an Android keyboard committing an image into the focused field.
///
/// Client id `-1` is Flutter's debug-mode id, which bypasses the active
/// connection-id check in the same way as the framework's insertion tests.
Future<void> commitKeyboardImage(
  WidgetTester tester, {
  String mimeType = 'image/gif',
}) {
  const uri =
      'content://com.google.android.inputmethod.latin.fileprovider/report.gif';
  final message = const JSONMessageCodec().encodeMessage(<String, dynamic>{
    'method': 'TextInputClient.performAction',
    'args': <dynamic>[
      -1,
      'TextInputAction.commitContent',
      <String, dynamic>{
        'mimeType': mimeType,
        'data': <int>[0, 1, 0, 1, 0, 1],
        'uri': uri,
      },
    ],
  });
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    message,
    (ByteData? _) {},
  );
}
