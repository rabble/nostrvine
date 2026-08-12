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
  /// make undo a no-op.
  ///
  /// The superseded still stays on disk for the rest of the session so undo
  /// can reach it; `ClipEditorBloc` queues it with the editor session's
  /// deferred cleanup, which reference-checks and deletes it at session end.
  /// Nothing else would find it — `FileCleanupService` only sees paths handed
  /// to it explicitly, and `StorageManagementService` scans the temp directory
  /// for `.mp4` renders.
  ///
  /// Frames persist as a documents-relative basename (`StopMotionClipFrame`
  /// stores only the file name), so the documents directory is the only place
  /// the file may live.
  ///
  /// The `.jpg` name is only honest because `transformEditorConfigs` runs the
  /// editor on an `outputFormat` of JPEG; its test pins that so this name
  /// cannot start lying after a package bump.
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
