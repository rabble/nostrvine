// ABOUTME: Persists a crop/rotate/flip of a stop-motion still as a new file
// ABOUTME: The editor hands back pixels; this is where they become a frame

import 'dart:io';
import 'dart:typed_data';

import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// Writes a transformed stop-motion still to disk.
class StopMotionFrameTransformService {
  StopMotionFrameTransformService._();

  static const _logName = 'StopMotionFrameTransformService';

  /// Prefix of every file this service writes. Shared with the recorder's
  /// captured stills only in spirit — the name is distinct so a transformed
  /// still is recognisable on disk.
  static const _fileNamePrefix = 'stop_motion_frame_transformed';

  /// Writes [bytes] — the still as the crop-rotate editor rendered it — into
  /// the documents directory and returns the new file's path.
  ///
  /// Always a *new* file, never an overwrite of the source still: editor undo
  /// history keeps pointing at the original path, and duplicated stills share
  /// one file, so rewriting in place would silently transform every copy and
  /// make undo a no-op. The superseded file is intentionally left on disk for
  /// the same reason the clip transform leaves its input behind; the draft
  /// orphan sweep reclaims it once no clip references it.
  ///
  /// Frames persist as a documents-relative basename (`StopMotionClipFrame`
  /// stores only the file name), so the documents directory is the only place
  /// the file may live.
  ///
  /// Throws [FileSystemException] when the write fails; callers surface that
  /// rather than committing a frame that points at nothing.
  static Future<String> writeTransformedFrame(Uint8List bytes) async {
    final documentsPath = await getDocumentsPath();
    final outputPath = p.join(
      documentsPath,
      '${_fileNamePrefix}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    await File(outputPath).writeAsBytes(bytes, flush: true);

    Log.info(
      '🔳 Wrote transformed stop-motion still to $outputPath',
      name: _logName,
      category: LogCategory.video,
    );

    return outputPath;
  }
}
