// ABOUTME: Points the shared image_picker channel at a real file on disk.
// ABOUTME: The canonical handler answers with a path that was never written,
// ABOUTME: which flows validating the pick reject before any crop/upload runs.

import 'dart:io';

import 'package:flutter/services.dart';

import 'shared_channel_override.dart';

const MethodChannel imagePickerChannel = MethodChannel(
  'plugins.flutter.io/image_picker',
);

/// Writes [bytes] to `picked.jpg` inside [directory] and makes the mocked
/// picker answer `pickImage` with its path.
///
/// Pass an empty list to reproduce the zero-byte pick iOS occasionally hands
/// back, or `deleteSync()` the returned file to reproduce a pick whose file is
/// already gone. The override auto-restores the canonical handler on teardown.
File stubPickedImageFile(Directory directory, List<int> bytes) {
  final file = File('${directory.path}/picked.jpg')..writeAsBytesSync(bytes);
  overrideSharedChannel(imagePickerChannel, (call) async {
    return call.method == 'pickImage' ? file.path : null;
  });
  return file;
}
