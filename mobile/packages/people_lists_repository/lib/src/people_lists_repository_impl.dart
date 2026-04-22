// ABOUTME: NostrClient-backed implementation of PeopleListsRepository.
// ABOUTME: Treats publishEvent non-null return as submitted, never confirmed.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/local_people_lists_cache.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:people_lists_repository/src/people_list_search_result.dart';
import 'package:people_lists_repository/src/people_lists_repository.dart';

/// Logger name for repository-level diagnostics.
const String _logName = 'people_lists_repository.impl';

/// Log level for recoverable warnings. `dart:developer`'s convention is 900.
const int _logLevelWarning = 900;

/// Concrete [PeopleListsRepository] backed by a [NostrClient] and a
/// [LocalPeopleListsCache].
///
/// Submission semantics: a non-null return from [NostrClient.publishEvent]
/// means the event was signed and submitted to at least one relay socket. The
/// repository does not wait for a relay `OK`. On a null return or thrown
/// error, the operation is reported as [PeopleListPublishStatus.failed] and
/// no optimistic cache write is performed.
///
/// Constructor injection only — the repository never resolves dependencies
/// implicitly. All mutable state lives in the injected cache; the repository
/// itself is effectively stateless.
class PeopleListsRepositoryImpl implements PeopleListsRepository {
  /// Creates a repository bound to [nostrClient] and [cache].
  PeopleListsRepositoryImpl({
    required NostrClient nostrClient,
    required LocalPeopleListsCache cache,
  }) : _nostrClient = nostrClient,
       _cache = cache;

  final NostrClient _nostrClient;
  final LocalPeopleListsCache _cache;

  @override
  Stream<List<UserList>> watchLists({required String ownerPubkey}) {
    return _cache.watchLists(ownerPubkey: ownerPubkey);
  }

  @override
  Future<List<UserList>> readLists({required String ownerPubkey}) {
    return _cache.readLists(ownerPubkey: ownerPubkey);
  }

  @override
  Future<void> syncOwner({required String ownerPubkey}) async {
    final filter = Filter(
      kinds: const [Nip51PeopleListCodec.kind],
      authors: [ownerPubkey],
    );

    final events = await _nostrClient.queryEvents([filter]);
    if (events.isEmpty) return;

    // Index existing lists by id so we can skip stale relay echoes whose
    // createdAt is older than the locally-stored updatedAt. The cache alone
    // cannot make this decision because it compares against tombstones, not
    // against the current list's updatedAt.
    final existing = await _cache.readLists(ownerPubkey: ownerPubkey);
    final existingById = <String, UserList>{
      for (final list in existing) list.id: list,
    };

    final receivedAt = DateTime.now().toUtc();
    for (final event in events) {
      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      final current = existingById[list.id];
      // list.updatedAt is derived from the relay event's created_at by
      // Nip51PeopleListCodec, so comparing it against the cached list's
      // updatedAt correctly detects stale relay echoes. If the codec ever
      // stops sourcing updatedAt from created_at, revisit this guard.
      if (current != null && current.updatedAt.isAfter(list.updatedAt)) {
        continue;
      }
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: list,
        receivedAt: receivedAt,
      );
    }
  }

  @override
  Future<PeopleListPublishResult> createList({
    required String ownerPubkey,
    required String name,
    String? description,
    String? imageUrl,
    Iterable<String> initialPubkeys = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final list = UserList(
      id: _generateListId(now),
      name: name,
      description: description,
      imageUrl: imageUrl,
      pubkeys: List<String>.unmodifiable(initialPubkeys),
      createdAt: now,
      updatedAt: now,
    );
    return _publishListReplacement(ownerPubkey: ownerPubkey, list: list);
  }

  @override
  Future<PeopleListPublishResult> addPubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    final existing = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (existing == null) {
      return const PeopleListPublishResult.failed();
    }
    if (existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    final updated = existing.copyWith(
      pubkeys: [...existing.pubkeys, pubkey],
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(ownerPubkey: ownerPubkey, list: updated);
  }

  @override
  Future<PeopleListPublishResult> removePubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    final existing = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (existing == null) {
      return const PeopleListPublishResult.failed();
    }
    if (!existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    final updated = existing.copyWith(
      pubkeys: existing.pubkeys.where((p) => p != pubkey).toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(ownerPubkey: ownerPubkey, list: updated);
  }

  @override
  Future<PeopleListPublishResult> deleteList({
    required String ownerPubkey,
    required String listId,
  }) async {
    final addressableId = '${Nip51PeopleListCodec.kind}:$ownerPubkey:$listId';
    final tags = <List<String>>[
      ['a', addressableId],
      ['k', '${Nip51PeopleListCodec.kind}'],
    ];
    final event = Event(
      ownerPubkey,
      EventKind.eventDeletion,
      tags,
      'Deleted people list $listId',
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent == null) {
        return const PeopleListPublishResult.failed();
      }
      await _cache.markDeleted(
        ownerPubkey: ownerPubkey,
        listId: listId,
        deletedAt: DateTime.now().toUtc(),
      );
      return PeopleListPublishResult.submitted(eventId: sent.id);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to publish people-list deletion for list $listId',
        name: _logName,
        level: _logLevelWarning,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  }

  @override
  Stream<List<PeopleListSearchResult>> searchPublicLists(
    String query, {
    int limit = 50,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final lowerQuery = trimmed.toLowerCase();

    final List<Event> events;
    try {
      events = await _nostrClient.queryEvents(
        [
          Filter(kinds: const [Nip51PeopleListCodec.kind], limit: limit),
        ],
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to query public people lists for "$trimmed"',
        name: _logName,
        level: _logLevelWarning,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final seen = <String, PeopleListSearchResult>{};
    for (final event in events) {
      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      if (list.pubkeys.isEmpty) continue;

      final nameMatches = list.name.toLowerCase().contains(lowerQuery);
      final descriptionMatches =
          list.description?.toLowerCase().contains(lowerQuery) ?? false;
      if (!nameMatches && !descriptionMatches) continue;

      final result = PeopleListSearchResult(
        ownerPubkey: event.pubkey,
        list: list,
      );
      final existing = seen[result.addressableId];
      if (existing != null && existing.list.updatedAt.isAfter(list.updatedAt)) {
        continue;
      }
      seen[result.addressableId] = result;
    }

    if (seen.isNotEmpty) {
      yield List.unmodifiable(seen.values.toList());
    }
  }

  Future<PeopleListPublishResult> _publishListReplacement({
    required String ownerPubkey,
    required UserList list,
  }) async {
    final payload = Nip51PeopleListCodec.encode(list);
    final event = Event(
      ownerPubkey,
      payload.kind,
      payload.tags,
      payload.content,
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent == null) {
        return const PeopleListPublishResult.failed();
      }
      final persisted = list.copyWith(nostrEventId: sent.id);
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: persisted,
        receivedAt: DateTime.now().toUtc(),
      );
      return PeopleListPublishResult.submitted(eventId: sent.id);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to publish people-list replacement for list ${list.id}',
        name: _logName,
        level: _logLevelWarning,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  }

  Future<UserList?> _findList({
    required String ownerPubkey,
    required String listId,
  }) async {
    final lists = await _cache.readLists(ownerPubkey: ownerPubkey);
    for (final list in lists) {
      if (list.id == listId) return list;
    }
    return null;
  }

  /// Generates a NIP-33 `d`-tag list identifier from [instant].
  ///
  /// NIP-33 parameterised replaceable events are identified by
  /// `kind:pubkey:d-tag`; callers pick any string. We combine the instant's
  /// microsecond epoch with a short entropy tail derived from a fresh
  /// `Object` identity hash so two `createList` calls that land in the same
  /// microsecond still produce distinct ids and do not clobber each other
  /// via NIP-33 replacement.
  String _generateListId(DateTime instant) {
    final entropy = Object().hashCode.toRadixString(36);
    return 'list-${instant.microsecondsSinceEpoch}-$entropy';
  }
}
