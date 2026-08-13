// ABOUTME: Native stub for the browser file-download helper.
// ABOUTME: Conditional import keeps package:web off every non-web build.

import 'dart:typed_data';

/// Native counterpart of [downloadBytesAsFile] on web.
///
/// Every call site is behind a `kIsWeb` guard, so reaching this on a native
/// build is a programming error rather than a runtime condition — it throws
/// instead of reporting a download that never happened.
void downloadBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('Browser downloads are only available on web');
}
