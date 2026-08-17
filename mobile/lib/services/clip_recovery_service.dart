// ABOUTME: Developer-only rescue for locally recorded clips that went missing.
// ABOUTME: Finds rows under other owners and unreferenced files, and reattaches
// ABOUTME: both to the signed-in account.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:openvine/services/video_editor/clip_media_duration.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Recovers recordings the app can no longer show.
///
/// Two failure modes leave a user staring at an empty library while the
/// recordings are still on the device, and this service addresses both:
///
/// * **Rows under another owner.** Every drafts/clips query filters by
///   `ownerPubkey`, so a session that resolved to a different account — or a
///   recording stamped before a session had resolved at all — is invisible
///   rather than gone. [scanRecoverableClips] reports those groups and
///   [claimOwnerGroup] restamps one to the signed-in account.
/// * **Rows gone, files left.** A database reset drops every clip row while
///   the mp4s stay in the documents directory. [scanRecoverableClips] lists
///   the unreferenced files and [importOrphanFiles] rebuilds library rows for
///   them.
///
/// Both are developer-tool operations: they write, and the owner restamp in
/// particular hands another account's rows to the current one. The caller is
/// expected to show the scan before offering either.
class ClipRecoveryService {
  /// Creates a service.
  ///
  /// [clipLibrary] is scoped to the signed-in account and supplies both the
  /// owner to recover *to* and the save path that stamps it. The DAOs are
  /// deliberately unscoped — the whole point is to see rows the scoped queries
  /// hide.
  ClipRecoveryService({
    required ClipsDao clipsDao,
    required DraftsDao draftsDao,
    required ClipCategoriesDao clipCategoriesDao,
    required ClipLibraryService clipLibrary,
    @visibleForTesting Future<Directory> Function()? documentsDirectoryProvider,
    @visibleForTesting
    Future<VideoMetadata> Function(String videoPath)? metadataProvider,
    @visibleForTesting
    Future<String?> Function(String videoPath)? thumbnailProvider,
  }) : _clipsDao = clipsDao,
       _draftsDao = draftsDao,
       _clipCategoriesDao = clipCategoriesDao,
       _clipLibrary = clipLibrary,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _metadataProvider = metadataProvider ?? _readMetadata,
       _thumbnailProvider = thumbnailProvider ?? _extractThumbnail;

  final ClipsDao _clipsDao;
  final DraftsDao _draftsDao;
  final ClipCategoriesDao _clipCategoriesDao;
  final ClipLibraryService _clipLibrary;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<VideoMetadata> Function(String videoPath) _metadataProvider;
  final Future<String?> Function(String videoPath) _thumbnailProvider;

  static const String _logName = 'ClipRecoveryService';

  /// Extensions a recovered recording can have.
  static const Set<String> _videoExtensions = {'.mp4', '.mov'};

  /// Suffix the recorder gives the working copy it makes while reading
  /// metadata. It is a duplicate of a real clip, not a recording of its own,
  /// so importing it would double every rescued clip.
  static const String _workCopySuffix = '.work.mp4';

  static Future<VideoMetadata> _readMetadata(String videoPath) =>
      ProVideoEditor.instance.getMetadata(EditorVideo.file(File(videoPath)));

  static Future<String?> _extractThumbnail(String videoPath) async {
    final result = await VideoThumbnailService.extractThumbnail(
      videoPath: videoPath,
    );
    return result?.path;
  }

  /// Reports every locally stored recording, grouped by the owner it is
  /// stamped with, plus the video files no row references.
  Future<ClipRecoveryReport> scanRecoverableClips() async {
    final currentOwner = _clipLibrary.ownerPubkey;

    // Unscoped on purpose: a null owner makes the DAO's owner predicate a
    // constant true, which is the only way to see the rows the scoped queries
    // filter out. Trashed rows are included — a clip in the bin is still a
    // clip the user can restore.
    final clipRows = await _clipsDao.getAllClips(includeTrashed: true);
    final draftRows = await _draftsDao.getAllDrafts();

    final clipCounts = <String?, int>{};
    final newestRecordedAt = <String?, DateTime>{};
    for (final row in clipRows) {
      clipCounts.update(row.ownerPubkey, (v) => v + 1, ifAbsent: () => 1);
      final newest = newestRecordedAt[row.ownerPubkey];
      if (newest == null || row.recordedAt.isAfter(newest)) {
        newestRecordedAt[row.ownerPubkey] = row.recordedAt;
      }
    }

    final draftCounts = <String?, int>{};
    for (final row in draftRows) {
      draftCounts.update(row.ownerPubkey, (v) => v + 1, ifAbsent: () => 1);
    }

    final foreignOwners = {...clipCounts.keys, ...draftCounts.keys}
      ..remove(currentOwner);
    final foreignGroups =
        [
          for (final owner in foreignOwners)
            ClipOwnerGroup(
              ownerPubkey: owner,
              clipCount: clipCounts[owner] ?? 0,
              draftCount: draftCounts[owner] ?? 0,
              newestRecordedAt: newestRecordedAt[owner],
            ),
        ]..sort((a, b) {
          final byClips = b.clipCount.compareTo(a.clipCount);
          return byClips != 0 ? byClips : b.draftCount.compareTo(a.draftCount);
        });

    return ClipRecoveryReport(
      currentOwnerPubkey: currentOwner,
      ownedClipCount: clipCounts[currentOwner] ?? 0,
      ownedDraftCount: draftCounts[currentOwner] ?? 0,
      foreignGroups: foreignGroups,
      orphanFiles: await _findOrphanFiles(),
    );
  }

  /// Video files in the documents directory that no clip or draft row
  /// references, largest first.
  ///
  /// Unreferenced is judged against *every* row rather than the current
  /// account's, so a file belonging to a hidden owner group is not offered
  /// here as well — claiming that group is the right fix for it, and importing
  /// would duplicate the clip under a second row.
  Future<List<OrphanClipFile>> _findOrphanFiles() async {
    final documents = await _documentsDirectoryProvider();
    if (!documents.existsSync()) return const [];

    final candidates = <File>[];
    try {
      // Non-recursive: the camera writes recordings straight into the
      // documents root, and descending would drag in the database directory
      // and every package's private storage.
      await for (final entity in documents.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!_videoExtensions.contains(p.extension(name).toLowerCase())) {
          continue;
        }
        if (name.endsWith(_workCopySuffix)) continue;
        if (TempRenderJanitor.isTempRenderName(name)) continue;
        candidates.add(entity);
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: listing ${documents.path} failed: $error',
        name: _logName,
        category: LogCategory.video,
      );
      return const [];
    }
    if (candidates.isEmpty) return const [];

    final referenced = await _clipsDao.referencedFilenames(
      candidates.map((file) => p.basename(file.path)).toSet(),
    );

    final orphans = <OrphanClipFile>[];
    for (final file in candidates) {
      final name = p.basename(file.path);
      if (referenced.contains(name)) continue;
      if (await _draftsDao.isDraftFileReferenced(name)) continue;
      try {
        // One stat rather than a length + lastModified pair, so a file
        // deleted mid-scan cannot report a size from before and a timestamp
        // from after.
        final stat = file.statSync();
        orphans.add(
          OrphanClipFile(
            path: file.path,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      } on Object catch (error) {
        // A file that vanished between listing and stat is not an orphan
        // worth reporting.
        Log.warning(
          '$_logName: could not stat ${file.path}: $error',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }

    orphans.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    return orphans;
  }

  /// Restamps every row owned by [group] onto the signed-in account, so its
  /// clips and drafts become visible again.
  ///
  /// Rows carrying no owner at all are swept up alongside it: that is the
  /// contract of the DAO's claim, and the same one sign-in already applies to
  /// them. So claiming any group also empties the unowned group, even though
  /// the report lists the two separately.
  ///
  /// Returns the number of clip rows moved. No-ops when no account is signed
  /// in — there would be nothing to move them to.
  Future<int> claimOwnerGroup(ClipOwnerGroup group) async {
    final newOwner = _clipLibrary.ownerPubkey;
    if (newOwner == null || newOwner.isEmpty) {
      Log.warning(
        '$_logName: refusing to claim without a signed-in account',
        name: _logName,
        category: LogCategory.video,
      );
      return 0;
    }

    final source = group.ownerPubkey;
    final movedClips = await _clipsDao.claimLegacyRows(
      newOwner,
      sourceOwnerPubkey: source,
    );
    await _draftsDao.claimLegacyRows(newOwner, sourceOwnerPubkey: source);
    await _clipCategoriesDao.claimLegacyRows(
      newOwner,
      sourceOwnerPubkey: source,
    );

    Log.info(
      '$_logName: claimed $movedClips clip row(s) from '
      '${source ?? '(unowned)'} for $newOwner',
      name: _logName,
      category: LogCategory.video,
    );
    return movedClips;
  }

  /// Rebuilds a library clip for each of [files] and saves it to the signed-in
  /// account's library.
  ///
  /// Only the video survives a database reset, so the rebuilt clip carries
  /// what can be read back off the file — duration, source resolution, a fresh
  /// thumbnail, and the file's modification time as the recording time.
  /// Everything the row used to hold about *intent* is gone for good: the lens
  /// metadata, the proof attestation, the ghost frame, and the aspect ratio the
  /// user had selected (a recording is stored at the sensor's ratio, so the
  /// crop choice left no trace in the file).
  ///
  /// Returns the clips that were rebuilt. A file whose metadata cannot be read
  /// is skipped and logged rather than failing the whole import.
  Future<List<DivineVideoClip>> importOrphanFiles(
    List<OrphanClipFile> files,
  ) async {
    final imported = <DivineVideoClip>[];
    for (final file in files) {
      try {
        final clip = await _rebuildClip(file);
        await _clipLibrary.saveClip(clip);
        imported.add(clip);
        Log.info(
          '$_logName: recovered ${file.path} as ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
      } on Object catch (error, stackTrace) {
        Log.error(
          '$_logName: could not recover ${file.path}: $error',
          name: _logName,
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return imported;
  }

  Future<DivineVideoClip> _rebuildClip(OrphanClipFile file) async {
    final metadata = await _metadataProvider(file.path);
    final duration = commonTrackEnd(metadata) ?? metadata.duration;
    final resolution = metadata.resolution;
    final sourceAspectRatio = resolution.height == 0
        ? null
        : resolution.width / resolution.height;

    return DivineVideoClip(
      // Namespaced and stamped with the source file so a second import of the
      // same file updates its row instead of stacking duplicates.
      id: 'recovered_${p.basenameWithoutExtension(file.path)}',
      video: EditorVideo.file(File(file.path)),
      duration: duration,
      recordedAt: file.modifiedAt,
      // The user's crop choice is unrecoverable; default to the app's own
      // default rather than inventing one from the sensor's ratio.
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: sourceAspectRatio,
      thumbnailPath: await _thumbnailProvider(file.path),
    );
  }
}
