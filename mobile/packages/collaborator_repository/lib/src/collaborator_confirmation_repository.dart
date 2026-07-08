// ABOUTME: Derives per-video collaborator confirmation status on mobile.
// ABOUTME: Subscribes to kind-34238 acceptance events for own-authored videos.

import 'dart:async';

import 'package:collaborator_repository/src/local_state_reader.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Divine collaborator response event kind (NIP-33 addressable, replaceable
/// per `(collaborator pubkey, video address)`). Mirrors the constant in
/// `mobile/lib/constants/collaboration_event_kinds.dart`; duplicated here to
/// keep the repository free of app-layer imports.
const int _kindCollaboratorResponse = 34238;

/// Composes the kind-34238 relay subscription, the cross-check against
/// creator-side `'collaborator'`-role p-tags, and the current user's local
/// invite-store fast-path into a single per-video status snapshot stream.
///
/// Scope guard: the kind-34238 subscription is only opened when the current
/// user authored the video. For other viewing contexts the repository emits
/// from the local-store fast-path (so the current user's own ignore/accept
/// flips their own avatar) without adding relay traffic. Third-party
/// rendering of pending collaborators is unchanged by this repository —
/// that broader fix lives in the lifecycle plan and depends on Funnelcake.
///
/// One subscription per `videoAddress`, ref-counted across watchers. The
/// underlying [NostrClient.subscribe] also dedupes by filter hash, so even
/// if the subscription opens twice it collapses to a single WebSocket
/// subscription at the transport layer.
class CollaboratorConfirmationRepository {
  CollaboratorConfirmationRepository({
    required NostrClient nostrClient,
    required CollaboratorInviteLocalStateReader localStateReader,
    required String currentUserPubkey,
  }) : _nostrClient = nostrClient,
       _localStateReader = localStateReader,
       _currentUserPubkey = currentUserPubkey;

  final NostrClient _nostrClient;
  final CollaboratorInviteLocalStateReader _localStateReader;
  final String _currentUserPubkey;

  /// Acceptance events observed from the relay, keyed by `videoAddress`.
  /// Each inner set contains collaborator pubkeys that have published a
  /// valid kind-34238 acceptance for that address.
  final Map<String, Set<String>> _relayAccepted = <String, Set<String>>{};

  /// Local fast-path overrides for the current user. Keyed by
  /// `videoAddress` → [CollaboratorStatus]. Only the current user's own
  /// pubkey is meaningful here.
  final Map<String, CollaboratorStatus> _currentUserOverride =
      <String, CollaboratorStatus>{};

  /// Per-video broadcast subjects. Created on first [watch], reused after.
  final Map<String, BehaviorSubject<VideoCollaboratorStatus>> _subjects =
      <String, BehaviorSubject<VideoCollaboratorStatus>>{};

  /// Per-video ref counts. Subscriptions close when count drops to zero.
  final Map<String, int> _refCount = <String, int>{};

  /// Per-video relay subscriptions. Only present for own-authored videos.
  final Map<String, StreamSubscription<Event>> _relaySubs =
      <String, StreamSubscription<Event>>{};

  /// Per-video cache of the most recent watch parameters. Lets
  /// [markLocal] re-emit a snapshot without callers having to thread the
  /// creator pubkey and tagged-pubkey list through every accept/ignore site.
  final Map<String, _WatchContext> _watchContext = <String, _WatchContext>{};

  /// Returns a stream of [VideoCollaboratorStatus] for [videoAddress].
  ///
  /// [creatorPubkey] is the author of the kind-34236 video event. Used to
  /// decide whether to open a kind-34238 relay subscription (only when the
  /// current user is the creator) and to key the local-store lookup.
  ///
  /// [taggedPubkeys] is the list of pubkeys tagged with the
  /// `'collaborator'` role on the latest creator-authored video event. Used
  /// to reject acceptance events from non-tagged pubkeys.
  ///
  /// Callers must call [release] with the same [videoAddress] when done to
  /// decrement the ref count and allow cleanup.
  Stream<VideoCollaboratorStatus> watch(
    String videoAddress, {
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) {
    _refCount[videoAddress] = (_refCount[videoAddress] ?? 0) + 1;
    _watchContext[videoAddress] = _WatchContext(
      creatorPubkey: creatorPubkey,
      taggedPubkeys: List.unmodifiable(taggedPubkeys),
    );

    final subject =
        _subjects.putIfAbsent(
            videoAddress,
            () => BehaviorSubject<VideoCollaboratorStatus>.seeded(
              _snapshot(
                videoAddress: videoAddress,
                creatorPubkey: creatorPubkey,
                taggedPubkeys: taggedPubkeys,
              ),
            ),
          )
          // Always re-emit a fresh snapshot so callers that arrive after
          // acceptance events have landed see the cached state immediately.
          ..add(
            _snapshot(
              videoAddress: videoAddress,
              creatorPubkey: creatorPubkey,
              taggedPubkeys: taggedPubkeys,
            ),
          );

    // Open the relay subscription on demand, only for own-authored videos.
    final isOwnVideo = creatorPubkey == _currentUserPubkey;
    if (isOwnVideo && !_relaySubs.containsKey(videoAddress)) {
      _relaySubs[videoAddress] = _nostrClient
          .subscribe([
            Filter(kinds: const [_kindCollaboratorResponse], a: [videoAddress]),
          ])
          .listen(
            (event) => _handleAcceptanceEvent(
              event,
              videoAddress: videoAddress,
              creatorPubkey: creatorPubkey,
              taggedPubkeys: taggedPubkeys,
            ),
            onError: (Object error, StackTrace stackTrace) {
              Log.warning(
                'kind-$_kindCollaboratorResponse subscription error for '
                '$videoAddress: $error',
                name: 'CollaboratorConfirmationRepository',
                category: LogCategory.system,
              );
            },
          );
    }

    return subject.stream;
  }

  /// Decrements the ref count for [videoAddress]; closes the subject and
  /// the relay subscription when the count drops to zero.
  void release(String videoAddress) {
    final current = _refCount[videoAddress] ?? 0;
    if (current <= 1) {
      _refCount.remove(videoAddress);
      unawaited(_relaySubs.remove(videoAddress)?.cancel());
      unawaited(_subjects.remove(videoAddress)?.close());
      _relayAccepted.remove(videoAddress);
      _currentUserOverride.remove(videoAddress);
      _watchContext.remove(videoAddress);
      return;
    }
    _refCount[videoAddress] = current - 1;
  }

  /// Returns the current synchronous status snapshot for [videoAddress].
  /// Returns an empty snapshot if the video is not being watched.
  VideoCollaboratorStatus current(String videoAddress) {
    final subject = _subjects[videoAddress];
    if (subject != null && subject.hasValue) {
      return subject.value;
    }
    return VideoCollaboratorStatus(videoAddress: videoAddress);
  }

  /// Local fast-path: records the current user's accept/ignore decision
  /// for a video they were invited to. Emits an updated snapshot to any
  /// active subscriber.
  ///
  /// Quietly drops writes for pubkeys other than the current user; the
  /// local store is per-device and only tracks the current user's own
  /// decisions.
  void markLocal({
    required String videoAddress,
    required String collaboratorPubkey,
    required CollaboratorStatus status,
  }) {
    if (collaboratorPubkey != _currentUserPubkey) {
      Log.warning(
        'markLocal called for non-current-user pubkey '
        '$collaboratorPubkey; ignoring',
        name: 'CollaboratorConfirmationRepository',
        category: LogCategory.system,
      );
      return;
    }
    _currentUserOverride[videoAddress] = status;
    final subject = _subjects[videoAddress];
    final context = _watchContext[videoAddress];
    if (subject != null && context != null) {
      subject.add(
        _snapshot(
          videoAddress: videoAddress,
          creatorPubkey: context.creatorPubkey,
          taggedPubkeys: context.taggedPubkeys,
        ),
      );
    }
  }

  /// Disposes all subjects and subscriptions. Used on sign-out / shutdown.
  Future<void> close() async {
    for (final sub in _relaySubs.values) {
      await sub.cancel();
    }
    _relaySubs.clear();
    for (final subject in _subjects.values) {
      await subject.close();
    }
    _subjects.clear();
    _refCount.clear();
    _relayAccepted.clear();
    _currentUserOverride.clear();
    _watchContext.clear();
  }

  void _handleAcceptanceEvent(
    Event event, {
    required String videoAddress,
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) {
    if (event.kind != _kindCollaboratorResponse) return;

    // NIP-33 'a' tag references another addressable event (the video). The
    // kind-34238 event's own 'd' tag identifies itself, not the video, so
    // only 'a' is semantically meaningful here.
    final addressMatches = event.tags.any(
      (tag) => tag.length >= 2 && tag[0] == 'a' && tag[1] == videoAddress,
    );
    if (!addressMatches) return;

    final hasAcceptedStatus = event.tags.any(
      (tag) => tag.length >= 2 && tag[0] == 'status' && tag[1] == 'accepted',
    );
    if (!hasAcceptedStatus) return;

    if (!taggedPubkeys.contains(event.pubkey)) {
      Log.info(
        'Ignoring kind-$_kindCollaboratorResponse from non-tagged pubkey '
        '${event.pubkey} for $videoAddress',
        name: 'CollaboratorConfirmationRepository',
        category: LogCategory.system,
      );
      return;
    }

    final accepted = _relayAccepted.putIfAbsent(videoAddress, () => <String>{});
    if (accepted.add(event.pubkey)) {
      final subject = _subjects[videoAddress];
      subject?.add(
        _snapshot(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          taggedPubkeys: taggedPubkeys,
        ),
      );
    }
  }

  VideoCollaboratorStatus _snapshot({
    required String videoAddress,
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) {
    final statusByPubkey = <String, CollaboratorStatus>{};
    final accepted = _relayAccepted[videoAddress] ?? const <String>{};
    final override = _currentUserOverride[videoAddress];

    for (final pubkey in taggedPubkeys) {
      // Relay-derived: kind-34238 acceptance event observed.
      if (accepted.contains(pubkey)) {
        statusByPubkey[pubkey] = CollaboratorStatus.confirmed;
        continue;
      }

      // Local-store fast-path for the current user only. Other pubkeys'
      // states are unknown to this device.
      if (pubkey == _currentUserPubkey) {
        final inMemory = override;
        if (inMemory != null) {
          statusByPubkey[pubkey] = inMemory;
          continue;
        }
        final fromStore = _localStateReader.readLocalState(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: pubkey,
        );
        if (fromStore != null) {
          statusByPubkey[pubkey] = fromStore;
          continue;
        }
      }

      statusByPubkey[pubkey] = CollaboratorStatus.pending;
    }

    return VideoCollaboratorStatus(
      videoAddress: videoAddress,
      statusByPubkey: statusByPubkey,
    );
  }
}

class _WatchContext {
  const _WatchContext({
    required this.creatorPubkey,
    required this.taggedPubkeys,
  });

  final String creatorPubkey;
  final List<String> taggedPubkeys;
}
