// ABOUTME: NostrClient-backed d=notify subscription list repository.
// ABOUTME: Serializes mutations so concurrent bell toggles cannot clobber.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:people_lists_repository/src/notify_subscriptions_repository.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

const String _logName = 'people_lists_repository.notify';

/// Title tag written on the notify list.
///
/// Only shown if another client renders the list; Divine hides it from the
/// user-facing list UI via `Nip51PeopleListCodec.reservedDTags`.
const String _notifyListTitle = 'Notify';

/// Concrete [NotifySubscriptionsRepository] backed by a [NostrClient].
///
/// Submission semantics match `PeopleListsRepositoryImpl`: a
/// [PublishSuccess] means the event reached at least one relay socket, not
/// that any relay persisted it.
///
/// ### Mutation serialization
///
/// Every bell toggle is a read-modify-write on one NIP-33 replaceable event.
/// Two concurrent toggles would each read the same base set and the second
/// publish would drop the first's change. Mutations are therefore chained
/// per owner: each awaits the previous one's completion and reads the set
/// that mutation produced, so a rapid on/off/on sequence converges instead
/// of racing.
///
/// The chain is per owner rather than per creator on purpose — all bells live
/// in a *single* event, so serializing per creator would still race.
class NotifySubscriptionsRepositoryImpl
    implements NotifySubscriptionsRepository {
  /// Creates a repository bound to [nostrClient].
  NotifySubscriptionsRepositoryImpl({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  final Map<String, _NotifyListSnapshot> _snapshots = {};
  final Map<String, BehaviorSubject<Set<String>>> _subjects = {};

  /// Tail of the per-owner mutation chain. Awaiting it serializes the next
  /// read-modify-write behind every mutation already queued.
  final Map<String, Future<void>> _mutationTails = {};

  bool _disposed = false;

  @override
  Future<Set<String>> readSubscriptions({required String ownerPubkey}) async {
    final snapshot = await _ensureSnapshot(ownerPubkey);
    return snapshot.creators;
  }

  @override
  Stream<Set<String>> watchSubscriptions({required String ownerPubkey}) {
    final subject = _subjectFor(ownerPubkey);
    // Seed asynchronously so a listener that subscribes before the first
    // relay read still receives the loaded set rather than only future
    // mutations.
    if (!_snapshots.containsKey(ownerPubkey)) {
      _ensureSnapshot(ownerPubkey).ignore();
    }
    return subject.stream;
  }

  @override
  Future<void> refresh({required String ownerPubkey}) async {
    final snapshot = await _readFromRelays(ownerPubkey);
    _publishSnapshot(ownerPubkey, snapshot);
  }

  @override
  Future<PeopleListPublishResult> subscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  }) {
    return _mutate(
      ownerPubkey: ownerPubkey,
      creatorPubkey: creatorPubkey,
      add: true,
    );
  }

  @override
  Future<PeopleListPublishResult> unsubscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  }) {
    return _mutate(
      ownerPubkey: ownerPubkey,
      creatorPubkey: creatorPubkey,
      add: false,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subject in _subjects.values) {
      await subject.close();
    }
    _subjects.clear();
    _snapshots.clear();
    _mutationTails.clear();
  }

  /// Queues a mutation behind every mutation already pending for [ownerPubkey].
  Future<PeopleListPublishResult> _mutate({
    required String ownerPubkey,
    required String creatorPubkey,
    required bool add,
  }) {
    final previous = _mutationTails[ownerPubkey] ?? Future<void>.value();
    final result = previous.then(
      (_) => _applyMutation(
        ownerPubkey: ownerPubkey,
        creatorPubkey: creatorPubkey,
        add: add,
      ),
    );
    // The tail must never carry an error, or every later mutation in the
    // chain would fail with the earlier one's error instead of running.
    _mutationTails[ownerPubkey] = result.then((_) {}, onError: (_, _) {});
    return result;
  }

  Future<PeopleListPublishResult> _applyMutation({
    required String ownerPubkey,
    required String creatorPubkey,
    required bool add,
  }) async {
    if (_disposed) return const PeopleListPublishResult.failed();
    if (creatorPubkey.isEmpty || creatorPubkey == ownerPubkey) {
      // Subscribing to your own posts is meaningless; the push service drops
      // self-references anyway, so never write one.
      return const PeopleListPublishResult.noop();
    }

    final snapshot = await _ensureSnapshot(ownerPubkey);
    final isSubscribed = snapshot.creators.contains(creatorPubkey);
    if (add == isSubscribed) {
      return const PeopleListPublishResult.noop();
    }

    final updated = <String>{...snapshot.creators};
    if (add) {
      updated.add(creatorPubkey);
    } else {
      updated.remove(creatorPubkey);
    }

    return _publishReplacement(
      ownerPubkey: ownerPubkey,
      creators: updated,
      previousCreatedAt: snapshot.createdAt,
    );
  }

  /// Publishes the full list. A partial list would be a destructive write:
  /// the event is replaceable, so omitted members are removed.
  Future<PeopleListPublishResult> _publishReplacement({
    required String ownerPubkey,
    required Set<String> creators,
    required int previousCreatedAt,
  }) async {
    final payload = Nip51PeopleListCodec.encodeReserved(
      dTag: Nip51PeopleListCodec.notifyDTag,
      title: _notifyListTitle,
      pubkeys: creators,
    );

    // NIP-33 replacement resolves by created_at, and relay behaviour for a
    // tie is unspecified. Two toggles inside the same second would otherwise
    // be a coin flip over which survives, so step past the previous event.
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final createdAt = nowSeconds > previousCreatedAt
        ? nowSeconds
        : previousCreatedAt + 1;

    final event = Event(
      ownerPubkey,
      payload.kind,
      payload.tags,
      payload.content,
      createdAt: createdAt,
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent is! PublishSuccess) {
        Log.warning(
          'Notify list publish returned no event for owner $ownerPubkey',
          name: _logName,
          category: LogCategory.relay,
        );
        return const PeopleListPublishResult.failed();
      }
      _publishSnapshot(
        ownerPubkey,
        _NotifyListSnapshot(creators: creators, createdAt: createdAt),
      );
      return PeopleListPublishResult.submitted(eventId: sent.event.id);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to publish notify list for owner $ownerPubkey',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      // Snapshot intentionally untouched so the caller can revert optimistic
      // UI and a retry re-reads the unchanged base set.
      return PeopleListPublishResult.failed(error: error);
    }
  }

  Future<_NotifyListSnapshot> _ensureSnapshot(String ownerPubkey) async {
    final cached = _snapshots[ownerPubkey];
    if (cached != null) return cached;
    final loaded = await _readFromRelays(ownerPubkey);
    // A mutation may have published while the relay read was in flight; that
    // snapshot is newer than what the relay returned, so keep it.
    final current = _snapshots[ownerPubkey];
    if (current != null && current.createdAt >= loaded.createdAt) {
      return current;
    }
    _publishSnapshot(ownerPubkey, loaded);
    return loaded;
  }

  /// Reads the newest `d=notify` event for [ownerPubkey].
  ///
  /// Relays may return several replaceable generations; the highest
  /// `created_at` wins. A read failure yields an empty snapshot so the bell
  /// renders "off" rather than blocking, and a later [refresh] can correct it.
  Future<_NotifyListSnapshot> _readFromRelays(String ownerPubkey) async {
    final filter = Filter(
      kinds: const [Nip51PeopleListCodec.kind],
      authors: [ownerPubkey],
      d: const [Nip51PeopleListCodec.notifyDTag],
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      var newest = const _NotifyListSnapshot(creators: {}, createdAt: 0);
      for (final event in events) {
        final members = Nip51PeopleListCodec.decodeReservedMembers(
          event,
          dTag: Nip51PeopleListCodec.notifyDTag,
        );
        if (members == null) continue;
        if (event.createdAt < newest.createdAt) continue;
        newest = _NotifyListSnapshot(
          creators: members.toSet(),
          createdAt: event.createdAt,
        );
      }
      return newest;
    } on Object catch (error) {
      Log.warning(
        'Failed to read notify list for owner $ownerPubkey: $error',
        name: _logName,
        category: LogCategory.relay,
      );
      return const _NotifyListSnapshot(creators: {}, createdAt: 0);
    }
  }

  void _publishSnapshot(String ownerPubkey, _NotifyListSnapshot snapshot) {
    if (_disposed) return;
    _snapshots[ownerPubkey] = snapshot;
    final subject = _subjects[ownerPubkey];
    if (subject != null && !subject.isClosed) {
      subject.add(snapshot.creators);
    }
  }

  BehaviorSubject<Set<String>> _subjectFor(String ownerPubkey) {
    return _subjects.putIfAbsent(ownerPubkey, () {
      final seed = _snapshots[ownerPubkey]?.creators ?? const <String>{};
      return BehaviorSubject<Set<String>>.seeded(seed);
    });
  }
}

/// Immutable view of the notify list plus the `created_at` it was read at.
///
/// The timestamp is kept so the next publish can step past it — see
/// `_publishReplacement`.
class _NotifyListSnapshot {
  const _NotifyListSnapshot({required this.creators, required this.createdAt});

  final Set<String> creators;
  final int createdAt;
}
