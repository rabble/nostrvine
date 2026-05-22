// ABOUTME: Parses queued collaborator invite DMs from outgoing_dms and
// ABOUTME: retries unresolved recipient deliveries via queue recovery.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_sdk/event.dart';
import 'package:unified_logger/unified_logger.dart';

class PendingCollaboratorInvite extends Equatable {
  const PendingCollaboratorInvite({
    required this.rumorId,
    required this.collaboratorPubkey,
    required this.creatorPubkey,
    required this.videoAddress,
    required this.recipientWrapStatus,
    required this.selfWrapStatus,
    required this.retryCount,
    required this.queuedAt,
    this.title,
    this.thumbnailUrl,
    this.relayHint,
    this.lastError,
  });

  final String rumorId;
  final String collaboratorPubkey;
  final String creatorPubkey;
  final String videoAddress;
  final String? title;
  final String? thumbnailUrl;
  final String? relayHint;
  final OutgoingWrapStatus recipientWrapStatus;
  final OutgoingWrapStatus selfWrapStatus;
  final int retryCount;
  final DateTime queuedAt;
  final String? lastError;

  bool get requiresRecipientRecovery =>
      recipientWrapStatus != OutgoingWrapStatus.sent;

  @override
  List<Object?> get props => [
    rumorId,
    collaboratorPubkey,
    creatorPubkey,
    videoAddress,
    title,
    thumbnailUrl,
    relayHint,
    recipientWrapStatus,
    selfWrapStatus,
    retryCount,
    queuedAt,
    lastError,
  ];
}

class PendingCollaboratorInviteGroup extends Equatable {
  const PendingCollaboratorInviteGroup({
    required this.creatorPubkey,
    required this.videoAddress,
    required this.invites,
    this.title,
    this.thumbnailUrl,
    this.relayHint,
  });

  final String creatorPubkey;
  final String videoAddress;
  final String? title;
  final String? thumbnailUrl;
  final String? relayHint;
  final List<PendingCollaboratorInvite> invites;

  int get inviteCount => invites.length;

  Set<String> get collaboratorPubkeys =>
      invites.map((invite) => invite.collaboratorPubkey).toSet();

  String? get lastError {
    for (final invite in invites) {
      final value = invite.lastError?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
    creatorPubkey,
    videoAddress,
    title,
    thumbnailUrl,
    relayHint,
    invites,
  ];
}

class CollaboratorInviteRetrySummary extends Equatable {
  const CollaboratorInviteRetrySummary({
    required this.attemptedCount,
    required this.successCount,
    required this.failureCount,
  });

  final int attemptedCount;
  final int successCount;
  final int failureCount;

  bool get allSucceeded => attemptedCount == successCount;

  @override
  List<Object?> get props => [attemptedCount, successCount, failureCount];
}

class CollaboratorInviteRecoveryService {
  CollaboratorInviteRecoveryService({
    required DmRepository dmRepository,
    required OutgoingDmsDao outgoingDmsDao,
    required String ownerPubkey,
  }) : _dmRepository = dmRepository,
       _outgoingDmsDao = outgoingDmsDao,
       _ownerPubkey = ownerPubkey;

  final DmRepository _dmRepository;
  final OutgoingDmsDao _outgoingDmsDao;
  final String _ownerPubkey;

  Stream<List<PendingCollaboratorInviteGroup>> watchPendingInviteGroups() {
    return _outgoingDmsDao.watchAllForOwner(_ownerPubkey).map((rows) {
      final pending = rows
          .map(_tryParseInvite)
          .whereType<PendingCollaboratorInvite>()
          .where((invite) => invite.requiresRecipientRecovery)
          .toList(growable: false);

      final grouped = <String, List<PendingCollaboratorInvite>>{};
      for (final invite in pending) {
        grouped.putIfAbsent(invite.videoAddress, () => []).add(invite);
      }

      final groups =
          grouped.entries
              .map((entry) {
                final invites = entry.value.toList(growable: false)
                  ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
                final first = invites.first;
                return PendingCollaboratorInviteGroup(
                  creatorPubkey: first.creatorPubkey,
                  videoAddress: first.videoAddress,
                  title: first.title,
                  thumbnailUrl: first.thumbnailUrl,
                  relayHint: first.relayHint,
                  invites: invites,
                );
              })
              .toList(growable: false)
            ..sort(
              (a, b) =>
                  b.invites.first.queuedAt.compareTo(a.invites.first.queuedAt),
            );

      return groups;
    });
  }

  Future<CollaboratorInviteRetrySummary> retryPendingInvitesForVideo({
    required String videoAddress,
    Iterable<String> collaboratorPubkeys = const [],
  }) async {
    final groups = await watchPendingInviteGroups().first;
    final targetPubkeys = collaboratorPubkeys.toSet();
    final matchingInvites = groups
        .where((group) => group.videoAddress == videoAddress)
        .expand((group) => group.invites)
        .where((invite) {
          if (targetPubkeys.isEmpty) return true;
          return targetPubkeys.contains(invite.collaboratorPubkey);
        })
        .toList(growable: false);

    if (matchingInvites.isEmpty) {
      return const CollaboratorInviteRetrySummary(
        attemptedCount: 0,
        successCount: 0,
        failureCount: 0,
      );
    }

    var attempted = 0;
    var success = 0;
    for (final invite in matchingInvites) {
      attempted++;
      try {
        final result = await _dmRepository.recoverFullSend(
          rumorId: invite.rumorId,
        );
        if (result.success) {
          success++;
        } else {
          Log.warning(
            'Collaborator invite retry failed for rumor ${invite.rumorId} '
            '(recipient=${invite.collaboratorPubkey}, '
            'video=${invite.videoAddress}): ${result.error}',
            name: 'CollaboratorInviteRecoveryService',
            category: LogCategory.video,
          );
        }
      } on Object catch (error, stackTrace) {
        Log.error(
          'Collaborator invite retry threw for rumor ${invite.rumorId} '
          '(recipient=${invite.collaboratorPubkey}, '
          'video=${invite.videoAddress}): $error',
          name: 'CollaboratorInviteRecoveryService',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return CollaboratorInviteRetrySummary(
      attemptedCount: attempted,
      successCount: success,
      failureCount: attempted - success,
    );
  }

  PendingCollaboratorInvite? _tryParseInvite(OutgoingDm row) {
    try {
      final json = jsonDecode(row.rumorEventJson);
      if (json is! Map<String, dynamic>) return null;
      final event = Event.fromJson(json);
      return _parseInviteFromEvent(event, row);
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Skipping outgoing_dms row ${row.id}; failed to parse '
        'collaborator invite rumor JSON: $error\n$stackTrace',
        name: 'CollaboratorInviteRecoveryService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  PendingCollaboratorInvite? _parseInviteFromEvent(
    Event event,
    OutgoingDm row,
  ) {
    if (!_hasInviteMarker(event.tags)) return null;

    final addressTag = _findTag(event.tags, 'a');
    final addressValue = _tagValue(addressTag);
    if (addressValue == null) return null;

    final creatorPubkey = _parseCreatorPubkey(addressValue);
    if (creatorPubkey == null || creatorPubkey != _ownerPubkey) return null;

    return PendingCollaboratorInvite(
      rumorId: row.id,
      collaboratorPubkey: row.recipientPubkey,
      creatorPubkey: creatorPubkey,
      videoAddress: addressValue,
      title: _tagValue(_findTag(event.tags, 'title')),
      thumbnailUrl: _tagValue(_findTag(event.tags, 'thumb')),
      relayHint: _nonEmpty(
        addressTag != null && addressTag.length >= 3 ? addressTag[2] : null,
      ),
      recipientWrapStatus: row.recipientWrapStatus,
      selfWrapStatus: row.selfWrapStatus,
      retryCount: row.retryCount,
      queuedAt: row.queuedAt,
      lastError: row.recipientWrapLastError ?? row.selfWrapLastError,
    );
  }

  bool _hasInviteMarker(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == 'divine' && tag[1] == 'collab-invite') {
        return true;
      }
    }
    return false;
  }

  List<String>? _findTag(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == name) {
        return tag;
      }
    }
    return null;
  }

  String? _tagValue(List<String>? tag) {
    if (tag == null || tag.length < 2) return null;
    return _nonEmpty(tag[1]);
  }

  String? _parseCreatorPubkey(String addressValue) {
    final parts = addressValue.split(':');
    if (parts.length < 3) return null;
    final pubkey = _nonEmpty(parts[1]);
    if (pubkey == null || pubkey.length != 64) return null;
    return pubkey;
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
