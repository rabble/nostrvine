// ABOUTME: Repository for loading sticker packs from Nostr relays.
// ABOUTME: Discovers emoji sets from multiple curator pubkeys AND the user's
// ABOUTME: Kind 10030 emoji list (NIP-51 "a" tag pointers to Kind 30030 sets).

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:sticker_pack_repository/src/exceptions.dart';
import 'package:sticker_pack_repository/src/models/models.dart';

/// Kind 30030 is a NIP-51 emoji set (addressable event).
const int _emojiSetKind = 30030;

/// Kind 10030 is a NIP-51 user emoji list (replaceable event).
///
/// Contains `"a"` tags pointing to Kind 30030 emoji sets the user subscribes
/// to, formatted as `["a", "30030:<pubkey>:<d-tag>"]`.
const int _userEmojiListKind = 10030;

/// A parsed `"a"` tag reference from a Kind 10030 event.
///
/// Format: `["a", "30030:<pubkey>:<d-tag>"]`
class _ATagReference {
  const _ATagReference({required this.pubkey, required this.dTag});

  final String pubkey;
  final String dTag;
}

/// Default limit for broad discovery queries.
///
/// Caps the number of Kind 30030 events fetched from relays when discovering
/// packs without author restrictions.
const int _discoveryLimit = 50;

/// Repository for loading Nostr sticker packs from multiple sources.
///
/// Discovers Kind 30030 emoji sets from three sources (in parallel):
/// 1. **Curated packs** — queried by curator pubkeys (e.g. Divine team)
/// 2. **User-subscribed packs** — resolved from the user's Kind 10030 emoji
///    list, which contains `"a"` tag pointers to Kind 30030 sets
/// 3. **Broad discovery** — queries Kind 30030 from all connected relays
///    without author restriction (capped at [_discoveryLimit])
///
/// Sticker packs are parsed from Nostr event tags:
/// - `d` tag: unique pack identifier
/// - `name` or `title` tag: human-readable name
/// - `picture` or `image` tag: optional pack thumbnail
/// - `emoji` tags: individual stickers (`["emoji", shortcode, imageUrl]`)
class StickerPackRepository {
  /// Creates a new sticker pack repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  /// - [curatorPubkeys]: Hex pubkeys of sticker pack curators
  /// - [userPubkey]: Optional hex pubkey of the current user; when provided,
  ///   the repository also fetches packs from the user's Kind 10030 emoji list
  StickerPackRepository({
    required NostrClient nostrClient,
    required List<String> curatorPubkeys,
    String? userPubkey,
    List<String> discoveryRelays = const [],
  }) : _nostrClient = nostrClient,
       _curatorPubkeys = curatorPubkeys,
       _userPubkey = userPubkey,
       _discoveryRelays = discoveryRelays;

  final NostrClient _nostrClient;
  final List<String> _curatorPubkeys;
  final String? _userPubkey;

  /// General-purpose relay URLs used for discovering Kind 30030 emoji sets.
  ///
  /// The app's primary relay may be specialized (e.g. video-only) and not
  /// store emoji sets. These relays are queried via `tempRelays` to find
  /// packs from the broader Nostr network.
  final List<String> _discoveryRelays;

  /// Cached sticker packs from the last successful load.
  List<StickerPack>? _cachedPacks;

  /// Loads sticker packs from all sources.
  ///
  /// Queries three sources in parallel:
  /// 1. Curated packs from [_curatorPubkeys]
  /// 2. User-subscribed packs from Kind 10030 emoji list
  /// 3. Broad discovery from connected relays (no author filter)
  ///
  /// Results are merged and deduplicated by `authorPubkey:id` composite key.
  /// Curated and user-subscribed packs take priority over discovered packs.
  ///
  /// Returns a list of [StickerPack] models.
  ///
  /// Throws [LoadStickerPacksFailedException] if the query fails.
  Future<List<StickerPack>> loadStickerPacks() async {
    if (_cachedPacks != null) return _cachedPacks!;

    try {
      final results = await Future.wait([
        _loadCuratedPacks(),
        _loadUserSubscribedPacks(),
        _discoverPacks(),
      ]);

      final allPacks = <String, StickerPack>{};
      for (final packList in results) {
        for (final pack in packList) {
          final key = '${pack.authorPubkey}:${pack.id}';
          allPacks.putIfAbsent(key, () => pack);
        }
      }

      _cachedPacks = allPacks.values.toList();
      return _cachedPacks!;
    } on Exception catch (e) {
      throw LoadStickerPacksFailedException(
        'Failed to load sticker packs: $e',
      );
    }
  }

  /// Loads curated packs from all curator pubkeys.
  Future<List<StickerPack>> _loadCuratedPacks() async {
    if (_curatorPubkeys.isEmpty) return [];

    final filter = Filter(
      kinds: const [_emojiSetKind],
      authors: _curatorPubkeys,
    );

    final events = await _nostrClient.queryEvents([filter]);
    return _eventsToStickerPacks(events);
  }

  /// Loads packs the user subscribes to via their Kind 10030 emoji list.
  ///
  /// 1. Fetches the user's Kind 10030 event
  /// 2. Parses `"a"` tags to get Kind 30030 references
  /// 3. Groups references by author pubkey and queries Kind 30030 events
  Future<List<StickerPack>> _loadUserSubscribedPacks() async {
    final userPubkey = _userPubkey;
    if (userPubkey == null) return [];

    final emojiListFilter = Filter(
      kinds: const [_userEmojiListKind],
      authors: [userPubkey],
    );

    final emojiListEvents = await _nostrClient.queryEvents([emojiListFilter]);
    if (emojiListEvents.isEmpty) return [];

    // Use the most recent Kind 10030 event (replaceable event).
    emojiListEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final refs = _parseATagReferences(emojiListEvents.first);
    if (refs.isEmpty) return [];

    // Group by author pubkey so we can batch queries.
    final byAuthor = <String, List<String>>{};
    for (final ref in refs) {
      byAuthor.putIfAbsent(ref.pubkey, () => []).add(ref.dTag);
    }

    final packs = <StickerPack>[];
    for (final entry in byAuthor.entries) {
      final filter = Filter(
        kinds: const [_emojiSetKind],
        authors: [entry.key],
        d: entry.value,
      );
      final events = await _nostrClient.queryEvents([filter]);
      packs.addAll(_eventsToStickerPacks(events));
    }

    return packs;
  }

  /// Discovers packs from general-purpose relays without author restriction.
  ///
  /// Queries [_discoveryRelays] via `tempRelays` since the app's primary
  /// relay may be specialized (video-only) and not store Kind 30030 events.
  /// Limited to [_discoveryLimit] events to avoid overwhelming the UI.
  Future<List<StickerPack>> _discoverPacks() async {
    if (_discoveryRelays.isEmpty) return [];

    final filter = Filter(
      kinds: const [_emojiSetKind],
      limit: _discoveryLimit,
    );

    final events = await _nostrClient.queryEvents(
      [filter],
      tempRelays: List.of(_discoveryRelays),
    );
    return _eventsToStickerPacks(events);
  }

  /// Parses `"a"` tags from a Kind 10030 event into [_ATagReference]s.
  ///
  /// Only tags matching the format `"30030:<pubkey>:<d-tag>"` are returned.
  /// Malformed tags are silently skipped.
  List<_ATagReference> _parseATagReferences(Event event) {
    final refs = <_ATagReference>[];
    for (final rawTag in event.tags) {
      final tag = rawTag as List<dynamic>;
      if (tag.length < 2) continue;
      if (tag[0] as String != 'a') continue;

      final value = tag[1] as String;
      final parts = value.split(':');
      if (parts.length < 3) continue;
      if (parts[0] != '$_emojiSetKind') continue;

      final pubkey = parts[1];
      final dTag = parts.sublist(2).join(':');
      if (pubkey.isEmpty || dTag.isEmpty) continue;

      refs.add(_ATagReference(pubkey: pubkey, dTag: dTag));
    }
    return refs;
  }

  /// Converts a list of events to sticker packs, filtering out invalid ones.
  List<StickerPack> _eventsToStickerPacks(List<Event> events) {
    return events
        .map(_eventToStickerPack)
        .where((pack) => pack != null && pack.stickers.isNotEmpty)
        .cast<StickerPack>()
        .toList();
  }

  /// Returns a specific sticker pack by its `d` tag identifier.
  ///
  /// Requires [loadStickerPacks] to have been called first.
  /// Returns `null` if no pack with the given [id] exists.
  StickerPack? getStickerPack(String id) {
    if (_cachedPacks == null) return null;
    for (final pack in _cachedPacks!) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// Clears the cached sticker packs, forcing a fresh fetch on next load.
  void clearCache() {
    _cachedPacks = null;
  }

  /// Parses a Kind 30030 Nostr event into a [StickerPack].
  ///
  /// Returns `null` if the event cannot be parsed.
  StickerPack? _eventToStickerPack(Event event) {
    try {
      String? dTag;
      String? title;
      String? imageUrl;
      final stickers = <Sticker>[];

      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;

        final tagType = tag[0] as String;

        switch (tagType) {
          case 'd':
            dTag = tag[1] as String;
          // NIP-51 spec uses `name`; some clients use `title`.
          case 'name' || 'title':
            title ??= tag[1] as String;
          // NIP-51 spec uses `picture`; some clients use `image`.
          case 'picture' || 'image':
            imageUrl ??= tag[1] as String;
          case 'emoji':
            if (tag.length >= 3) {
              stickers.add(
                Sticker(
                  shortcode: tag[1] as String,
                  imageUrl: tag[2] as String,
                ),
              );
            }
        }
      }

      if (dTag == null || dTag.isEmpty) return null;

      return StickerPack(
        id: dTag,
        title: title ?? dTag,
        imageUrl: imageUrl,
        stickers: stickers,
        authorPubkey: event.pubkey,
      );
    } on Exception {
      return null;
    }
  }
}
