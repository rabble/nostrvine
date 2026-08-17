// ABOUTME: What a clip-recovery scan found: rows under other owners, and
// ABOUTME: video files on disk that no row references any more.

import 'package:equatable/equatable.dart';
import 'package:openvine/utils/byte_size_format.dart';
import 'package:path/path.dart' as p;

/// Locally stored rows attributed to one owner.
///
/// Every drafts/clips query filters by owner, so a group whose
/// [ownerPubkey] is not the signed-in account is invisible in the app
/// while its rows and files are still fully intact.
class ClipOwnerGroup extends Equatable {
  /// Creates a group.
  const ClipOwnerGroup({
    required this.ownerPubkey,
    required this.clipCount,
    required this.draftCount,
    this.newestRecordedAt,
  });

  /// Hex pubkey the rows are stamped with.
  ///
  /// May be the anonymous marker, which is what recordings made before a
  /// session had resolved used to be stamped with — the reported failure this
  /// tool exists for.
  ///
  /// Never the unowned case: rows carrying no owner at all match every
  /// account's `owner = ? OR owner IS NULL` query, so they are already visible
  /// and the scan counts them that way instead of grouping them here.
  final String ownerPubkey;

  /// Clip rows under this owner, including trashed and draft-owned ones.
  final int clipCount;

  /// Draft rows under this owner.
  final int draftCount;

  /// Recording time of the newest clip, so an operator can tell a stale
  /// account apart from the one that just lost its recordings.
  final DateTime? newestRecordedAt;

  @override
  List<Object?> get props => [
    ownerPubkey,
    clipCount,
    draftCount,
    newestRecordedAt,
  ];
}

/// A recording in the documents directory that no clip or draft row
/// references — what a database reset leaves behind.
class OrphanClipFile extends Equatable {
  /// Creates an orphan file entry.
  const OrphanClipFile({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
    this.duration,
    this.previewPath,
  });

  /// Absolute path on this device.
  final String path;

  /// File size in bytes.
  final int sizeBytes;

  /// Last modification time, which for a recording is when it was shot.
  final DateTime modifiedAt;

  /// Playing length, or null when the file could not be read.
  ///
  /// A null duration is the scan's own verdict that this file is unlikely to
  /// restore into anything playable.
  final Duration? duration;

  /// A frame extracted during the scan, or null when none could be taken.
  ///
  /// Restoring is per file, so the operator has to be able to tell which
  /// recording a row is before pressing anything — a filename and a byte count
  /// cannot answer that.
  final String? previewPath;

  /// Filename without its directory.
  String get name => p.basename(path);

  @override
  List<Object?> get props => [
    path,
    sizeBytes,
    modifiedAt,
    duration,
    previewPath,
  ];
}

/// The result of a clip-recovery scan.
class ClipRecoveryReport extends Equatable {
  /// Creates a report.
  const ClipRecoveryReport({
    required this.currentOwnerPubkey,
    required this.ownedClipCount,
    required this.ownedDraftCount,
    required this.foreignGroups,
    required this.orphanFiles,
  });

  /// Nothing scanned yet.
  static const empty = ClipRecoveryReport(
    currentOwnerPubkey: null,
    ownedClipCount: 0,
    ownedDraftCount: 0,
    foreignGroups: [],
    orphanFiles: [],
  );

  /// The account the app is currently scoped to.
  final String? currentOwnerPubkey;

  /// Clip rows the current account can already see.
  final int ownedClipCount;

  /// Draft rows the current account can already see.
  final int ownedDraftCount;

  /// Groups owned by anyone else, largest first.
  final List<ClipOwnerGroup> foreignGroups;

  /// Unreferenced recordings, newest first.
  final List<OrphanClipFile> orphanFiles;

  /// Whether the scan found anything to recover.
  bool get hasRecoverableContent =>
      foreignGroups.isNotEmpty || orphanFiles.isNotEmpty;

  /// Clip rows held by owners other than the current account.
  int get foreignClipCount =>
      foreignGroups.fold(0, (sum, group) => sum + group.clipCount);

  /// Bytes held by the unreferenced files.
  int get orphanBytes =>
      orphanFiles.fold(0, (sum, file) => sum + file.sizeBytes);

  /// A plain-text report for pasting into a support thread.
  ///
  /// Deliberately unlocalized, matching the storage footprint report: it is
  /// read by whoever triages the case, not by the user. Pubkeys are printed in
  /// full — a truncated one cannot be matched against an account.
  String toReportText() {
    final buffer = StringBuffer()
      ..writeln('Divine clip recovery scan')
      ..writeln('Current owner: ${currentOwnerPubkey ?? '(none)'}')
      ..writeln(
        'Visible now: $ownedClipCount clip(s), $ownedDraftCount draft(s)',
      );

    if (foreignGroups.isEmpty) {
      buffer.writeln('Other owners: none');
    } else {
      buffer.writeln('Other owners:');
      for (final group in foreignGroups) {
        buffer
          ..writeln('  owner: ${group.ownerPubkey}')
          ..writeln(
            '    ${group.clipCount} clip(s), ${group.draftCount} draft(s)'
            '${group.newestRecordedAt == null ? '' : ', newest '
                      '${group.newestRecordedAt!.toIso8601String()}'}',
          );
      }
    }

    if (orphanFiles.isEmpty) {
      buffer.writeln('Unreferenced files: none');
    } else {
      buffer.writeln(
        'Unreferenced files: ${orphanFiles.length} '
        '(${formatByteSize(orphanBytes)}, $orphanBytes bytes)',
      );
      for (final file in orphanFiles) {
        // An unreadable length is the scan's verdict that this one probably
        // will not restore into anything playable, so it belongs in the report
        // rather than only on screen.
        final length = file.duration == null
            ? 'unreadable'
            : '${file.duration!.inMilliseconds}ms';
        buffer.writeln(
          '  ${formatByteSize(file.sizeBytes)}\t$length\t'
          '${file.modifiedAt.toIso8601String()}\t${file.path}',
        );
      }
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    currentOwnerPubkey,
    ownedClipCount,
    ownedDraftCount,
    foreignGroups,
    orphanFiles,
  ];
}
