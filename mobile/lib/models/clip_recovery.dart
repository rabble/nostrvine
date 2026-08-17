// ABOUTME: What a clip-recovery scan found: rows under other owners, and
// ABOUTME: video files on disk that no row references any more.

import 'package:equatable/equatable.dart';
import 'package:openvine/utils/byte_size_format.dart';

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

  /// Hex pubkey the rows are stamped with, or null for unowned legacy rows.
  ///
  /// May also be the anonymous marker, which is what recordings made before a
  /// session had resolved used to be stamped with.
  final String? ownerPubkey;

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

/// A video file in the documents directory that no clip or draft row
/// references — what a database reset leaves behind.
class OrphanClipFile extends Equatable {
  /// Creates an orphan file entry.
  const OrphanClipFile({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// Absolute path on this device.
  final String path;

  /// File size in bytes.
  final int sizeBytes;

  /// Last modification time, which for a recording is when it was shot.
  final DateTime modifiedAt;

  @override
  List<Object?> get props => [path, sizeBytes, modifiedAt];
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

  /// Unreferenced video files, largest first.
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
          ..writeln('  owner: ${group.ownerPubkey ?? '(unowned)'}')
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
        buffer.writeln(
          '  ${formatByteSize(file.sizeBytes)}\t'
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
