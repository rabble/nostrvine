// ABOUTME: Service for consuming Kind 1985 label events from labeler pubkeys
// ABOUTME: Caches labels in memory and checks content warnings for events

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/nostr_event_kinds.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// A content-warning label applied by a labeler to a target event or pubkey.
class ModerationLabel {
  const ModerationLabel({
    required this.labelerPubkey,
    required this.labelValue,
    required this.targetEventId,
    this.targetAddressableId,
    this.targetPubkey,
    this.confidence,
    this.source,
    this.isVerified = false,
  });

  /// Pubkey of the labeler who applied this label.
  final String labelerPubkey;

  /// The label value (e.g. "nudity", "sexual", "ai-generated").
  final String labelValue;

  /// Target event ID this label applies to, if any.
  final String? targetEventId;

  /// Target addressable id this label applies to, if any.
  final String? targetAddressableId;

  /// Target pubkey this label applies to, if any.
  final String? targetPubkey;

  /// Confidence score (0.0 to 1.0) from AI detection, if available.
  final double? confidence;

  /// Source of the detection (e.g. "hiveai", "human-moderator").
  final String? source;

  /// Whether the label has been verified by a human moderator.
  final bool isVerified;
}

/// Result of AI detection analysis for a video.
class AIDetectionResult {
  const AIDetectionResult({
    required this.score,
    this.source,
    this.isVerified = false,
  });

  /// AI generation likelihood score (0.0 to 1.0).
  final double score;

  /// Source of the detection (e.g. "hiveai", "human-moderator").
  final String? source;

  /// Whether the result has been verified by a human moderator.
  final bool isVerified;
}

/// Service for subscribing to Kind 1985 label events from labeler pubkeys.
///
/// Maintains an in-memory cache of labels keyed by target (event ID or pubkey).
/// Auto-subscribes to the Divine official labeler on init.
class ModerationLabelService {
  ModerationLabelService({
    required NostrClient nostrClient,
    required AuthService authService,
    required SharedPreferences sharedPreferences,
    bool Function()? canQueryRelays,
  }) : _nostrClient = nostrClient,
       _authService = authService,
       _prefs = sharedPreferences,
       _canQueryRelays = canQueryRelays ?? (() => true);

  final NostrClient _nostrClient;
  // ignore: unused_field
  final AuthService _authService;
  final SharedPreferences _prefs;
  final bool Function() _canQueryRelays;

  /// SharedPreferences key for subscribed labeler pubkeys.
  static const String _subscribedLabelersKey = 'subscribed_labeler_pubkeys';

  /// SharedPreferences key for using followed accounts as trusted labelers.
  static const String _followingModerationEnabledKey =
      'following_moderation_enabled';

  /// SharedPreferences key for the NIP-05 resolved moderation pubkey.
  static const String _resolvedPubkeyKey = 'divine_moderation_resolved_pubkey';

  /// SharedPreferences key for when the moderation pubkey was last resolved.
  static const String _resolvedAtKey = 'divine_moderation_resolved_at';

  static const String _contentWarningNamespace = 'content-warning';

  /// NIP-05 address for the Divine moderation identity.
  static const String divineModerationNip05 = kModerationNip05;

  /// Fallback pubkey when NIP-05 resolution fails — the key pinned in this
  /// build, which is also what the protected-minor gate anchors on.
  static const String fallbackModerationPubkeyHex = kModerationPubkeyHex;

  /// Cache TTL for NIP-05 resolved pubkey (24 hours).
  static const Duration _resolvedPubkeyTtl = Duration(hours: 24);

  /// Resolved Divine moderation pubkey (cache → NIP-05 → fallback).
  String _divineModerationPubkey = fallbackModerationPubkeyHex;

  /// The current Divine moderation pubkey (resolved via NIP-05 or fallback).
  String get divineModerationPubkeyHex => _divineModerationPubkey;

  /// Whether the Divine official labeler is currently subscribed.
  bool get isDivineLabelerSubscribed =>
      _subscribedLabelers.contains(_divineModerationPubkey);

  /// Subscribed labelers excluding the built-in Divine labeler.
  Set<String> get customLabelers =>
      _subscribedLabelers.difference({_divineModerationPubkey});

  /// Labels keyed by target event ID.
  final Map<String, List<ModerationLabel>> _labelsByEventId = {};

  /// Labels keyed by target addressable id (`a` tag).
  final Map<String, List<ModerationLabel>> _labelsByAddressableId = {};

  /// Labels keyed by target pubkey.
  final Map<String, List<ModerationLabel>> _labelsByPubkey = {};

  /// Labels keyed by content hash (from `x` tags).
  final Map<String, List<ModerationLabel>> _labelsByHash = {};

  /// Currently subscribed labeler pubkeys.
  final Set<String> _subscribedLabelers = {};

  /// Followed pubkeys currently acting as trusted labelers.
  final Set<String> _followedLabelers = {};

  /// Labelers whose historical labels have already been loaded.
  final Set<String> _loadedLabelers = {};

  /// Labelers currently being loaded from relays.
  final Map<String, Future<void>> _loadingLabelers = {};

  /// Active subscriptions.
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

  /// Whether persisted settings have been loaded.
  bool _loadedPersistedState = false;
  Future<void>? _loadPersistedStateFuture;

  /// Whether followed accounts should act as trusted labelers.
  bool _isFollowingModerationEnabled = false;

  /// Get all subscribed labeler pubkeys.
  Set<String> get subscribedLabelers => Set.unmodifiable(_subscribedLabelers);

  /// Whether followed accounts are enabled as trusted labelers.
  bool get isFollowingModerationEnabled => _isFollowingModerationEnabled;

  /// Initialize by loading persisted labeler subscriptions and subscribing.
  Future<void> initialize() async {
    await ensureLoaded();
    if (_canQueryRelays()) {
      await _refreshModerationPubkey();
    }
    await _syncSubscribedLabelersWithRelays();
  }

  /// Load persisted moderation settings without touching relays or NIP-05.
  Future<void> ensureLoaded() => _ensurePersistedStateLoaded();

  Future<void> _ensurePersistedStateLoaded() {
    if (_loadedPersistedState) return Future<void>.value();
    return _loadPersistedStateFuture ??= _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    try {
      // Use cache or fallback only. Remote NIP-05 refresh happens from
      // initialize(), which is called only from relay-ready paths.
      _adoptModerationPubkey(_cachedModerationPubkey(_prefs));

      final saved = _prefs.getStringList(_subscribedLabelersKey);
      if (saved != null) {
        _subscribedLabelers.addAll(saved);
      }
      _isFollowingModerationEnabled =
          _prefs.getBool(_followingModerationEnabledKey) ?? false;

      // Migrate retired pubkeys if present in stored subscriptions
      await _migrateLegacyPubkey();

      // Always subscribe to Divine labeler
      if (!_subscribedLabelers.contains(_divineModerationPubkey)) {
        _subscribedLabelers.add(_divineModerationPubkey);
      }

      _loadedPersistedState = true;

      Log.info(
        'ModerationLabelService loaded '
        '${_subscribedLabelers.length} labelers '
        '(moderation pubkey: $_divineModerationPubkey)',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error initializing ModerationLabelService: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } finally {
      _loadPersistedStateFuture = null;
    }
  }

  Future<void> _syncSubscribedLabelersWithRelays() async {
    for (final pubkey in _subscribedLabelers) {
      await subscribeToLabeler(pubkey);
    }
  }

  /// Subscribe to Kind 1985 events from a labeler pubkey.
  Future<void> subscribeToLabeler(String pubkey) async {
    if (_loadedLabelers.contains(pubkey)) return;
    final inFlight = _loadingLabelers[pubkey];
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _subscribeToLabelerInternal(pubkey);
    _loadingLabelers[pubkey] = future;
    try {
      await future;
    } finally {
      _loadingLabelers.remove(pubkey);
    }
  }

  Future<void> _subscribeToLabelerInternal(String pubkey) async {
    if (!_canQueryRelays()) {
      Log.debug(
        'Deferring labeler subscription until Nostr session is ready: $pubkey',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      final filter = Filter(
        authors: [pubkey],
        kinds: [NostrEventKinds.label], // NIP-32 label events
      );

      final events = await _nostrClient.queryEvents([filter]);

      events.forEach(_processLabelEvent);

      _loadedLabelers.add(pubkey);

      Log.debug(
        'Subscribed to labeler $pubkey, '
        'loaded ${events.length} label events',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error subscribing to labeler $pubkey: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Add a new labeler and persist.
  Future<void> addLabeler(String pubkey) async {
    await _ensurePersistedStateLoaded();
    _subscribedLabelers.add(pubkey);
    await _saveSubscribedLabelers();
    await subscribeToLabeler(pubkey);
  }

  /// Remove a labeler and clean up.
  Future<void> removeLabeler(String pubkey) async {
    await _ensurePersistedStateLoaded();
    // Don't allow removing the built-in Divine labeler
    if (pubkey == _divineModerationPubkey) return;

    _subscribedLabelers.remove(pubkey);
    await _saveSubscribedLabelers();
    if (!_followedLabelers.contains(pubkey)) {
      await _unloadLabeler(pubkey);
    }
  }

  /// Enable or disable followed accounts as trusted moderation labelers.
  Future<void> setFollowingModerationEnabled(
    bool enabled, {
    Iterable<String> followedPubkeys = const [],
  }) async {
    await _ensurePersistedStateLoaded();
    _isFollowingModerationEnabled = enabled;
    await _saveFollowingModerationEnabled();
    await _syncFollowedLabelersInternal(
      enabled ? followedPubkeys : const <String>[],
    );
  }

  /// Sync the currently followed pubkeys that should act as trusted labelers.
  Future<void> syncFollowedLabelers(Iterable<String> followedPubkeys) async {
    await _ensurePersistedStateLoaded();
    if (!_isFollowingModerationEnabled) return;
    await _syncFollowedLabelersInternal(followedPubkeys);
  }

  /// Get content-warning labels for a specific event ID.
  List<ModerationLabel> getContentWarnings(String eventId) {
    return _labelsByEventId[eventId] ?? const [];
  }

  /// Get content-warning labels for a specific addressable id (`a` tag).
  List<ModerationLabel> getContentWarningsByAddressableId(
    String addressableId,
  ) {
    return _labelsByAddressableId[addressableId] ?? const [];
  }

  /// Get content-warning labels for a specific content hash (`x` tag).
  List<ModerationLabel> getContentWarningsByHash(String sha256) {
    return _labelsByHash[sha256] ?? const [];
  }

  /// Get content-warning labels for a specific pubkey (account-level labels).
  List<ModerationLabel> getLabelsForPubkey(String pubkey) {
    return _labelsByPubkey[pubkey] ?? const [];
  }

  /// Get AI detection result for a specific event ID, if available.
  ///
  /// Looks for `ai-generated` labels from subscribed labelers.
  AIDetectionResult? getAIDetectionResult(String eventId) {
    final labels = _labelsByEventId[eventId];
    if (labels == null) return null;

    for (final label in labels) {
      if (label.labelValue == 'ai-generated' && label.confidence != null) {
        return AIDetectionResult(
          score: label.confidence!,
          source: label.source,
          isVerified: label.isVerified,
        );
      }
    }
    return null;
  }

  /// Get AI detection result by content hash (sha256).
  ///
  /// Useful when matching moderation results to videos via their content hash.
  AIDetectionResult? getAIDetectionByHash(String sha256) {
    final labels = _labelsByHash[sha256];
    if (labels == null) return null;

    for (final label in labels) {
      if (label.labelValue == 'ai-generated' && label.confidence != null) {
        return AIDetectionResult(
          score: label.confidence!,
          source: label.source,
          isVerified: label.isVerified,
        );
      }
    }
    return null;
  }

  /// Check if an event has any content-warning labels from subscribed labelers.
  bool hasContentWarning(String eventId) {
    return _labelsByEventId.containsKey(eventId) &&
        _labelsByEventId[eventId]!.isNotEmpty;
  }

  /// Process a Kind 1985 label event and cache its labels.
  void _processLabelEvent(dynamic event) {
    try {
      final tags = event.tags as List<dynamic>;
      final labelerPubkey = event.pubkey as String;

      final namespaces = <String>{};
      final labels = <_PendingModerationLabel>[];
      final eventIds = <String>[];
      final addressableIds = <String>[];
      final pubkeys = <String>[];
      final hashes = <String>[];

      for (final tag in tags) {
        if (tag is! List || tag.length < 2) continue;
        final tagName = tag[0];
        final tagValue = tag[1];
        if (tagName is! String || tagValue is! String) continue;

        switch (tagName) {
          case 'L':
            final namespace = _normalizeLabelNamespace(tagValue);
            if (namespace != null) {
              namespaces.add(namespace);
            }
          case 'l':
            final metadata = tag.length > 3 && tag[3] is String
                ? _parseMetadata(tag[3] as String)
                : null;
            labels.add(
              _PendingModerationLabel(
                value: tagValue,
                namespace: tag.length > 2 && tag[2] is String
                    ? _normalizeLabelNamespace(tag[2] as String)
                    : null,
                metadata: metadata,
              ),
            );
          case 'e':
            eventIds.add(tagValue);
          case 'a':
            addressableIds.add(tagValue);
          case 'p':
            pubkeys.add(tagValue);
          case 'x':
            hashes.add(tagValue);
        }
      }

      for (final pending in labels) {
        if (!_isContentWarningLabel(pending, namespaces)) continue;

        for (final eventId in eventIds) {
          _labelsByEventId
              .putIfAbsent(eventId, () => [])
              .add(
                pending.toModerationLabel(
                  labelerPubkey: labelerPubkey,
                  targetEventId: eventId,
                ),
              );
        }
        for (final addressableId in addressableIds) {
          _labelsByAddressableId
              .putIfAbsent(addressableId, () => [])
              .add(
                pending.toModerationLabel(
                  labelerPubkey: labelerPubkey,
                  targetAddressableId: addressableId,
                ),
              );
        }
        for (final pubkey in pubkeys) {
          _labelsByPubkey
              .putIfAbsent(pubkey, () => [])
              .add(
                pending.toModerationLabel(
                  labelerPubkey: labelerPubkey,
                  targetPubkey: pubkey,
                ),
              );
        }
        for (final hash in hashes) {
          _labelsByHash
              .putIfAbsent(hash, () => [])
              .add(pending.toModerationLabel(labelerPubkey: labelerPubkey));
        }
      }
    } catch (e) {
      Log.error(
        'Error processing label event: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  bool _isContentWarningLabel(
    _PendingModerationLabel label,
    Set<String> namespaces,
  ) {
    if (label.namespace == _contentWarningNamespace) return true;

    // Leniency for non-conforming publishers: NIP-32 requires an `l` mark
    // matching an `L` tag when `L` is present, but some events omit it. Accept
    // that only when the event declares exactly one namespace and it is
    // content-warning. With no `L`, unmarked `l` implies `ugc` and is ignored.
    return label.namespace == null &&
        namespaces.length == 1 &&
        namespaces.single == _contentWarningNamespace;
  }

  static String? _normalizeLabelNamespace(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  /// Parse JSON metadata from the 4th element of an `l` tag.
  ///
  /// Expected format:
  /// `{"confidence": 0.95, "verified": true, "source": "hiveai"}`
  _LabelMetadata? _parseMetadata(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _LabelMetadata(
        confidence: (data['confidence'] as num?)?.toDouble(),
        source: data['source'] as String?,
        isVerified: data['verified'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persist subscribed labeler pubkeys.
  Future<void> _saveSubscribedLabelers() async {
    try {
      await _prefs.setStringList(
        _subscribedLabelersKey,
        _subscribedLabelers.toList(),
      );
    } catch (e) {
      Log.error(
        'Error saving subscribed labelers: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Persist whether followed accounts are trusted moderation sources.
  Future<void> _saveFollowingModerationEnabled() async {
    try {
      await _prefs.setBool(
        _followingModerationEnabledKey,
        _isFollowingModerationEnabled,
      );
    } catch (e) {
      Log.error(
        'Error saving following moderation setting: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _syncFollowedLabelersInternal(
    Iterable<String> followedPubkeys,
  ) async {
    final normalized = followedPubkeys
        .where((pubkey) => pubkey.isNotEmpty)
        .toSet();

    final toRemove = _followedLabelers.difference(normalized);

    for (final pubkey in toRemove) {
      _followedLabelers.remove(pubkey);
      if (!_subscribedLabelers.contains(pubkey)) {
        await _unloadLabeler(pubkey);
      }
    }

    for (final pubkey in normalized) {
      _followedLabelers.add(pubkey);
      if (!_subscribedLabelers.contains(pubkey) &&
          !_loadedLabelers.contains(pubkey)) {
        await subscribeToLabeler(pubkey);
      }
    }
  }

  Future<void> _unloadLabeler(String pubkey) async {
    await _subscriptions[pubkey]?.cancel();
    _subscriptions.remove(pubkey);
    _loadedLabelers.remove(pubkey);
    _removeLabelsForLabeler(pubkey);
  }

  void _removeLabelsForLabeler(String pubkey) {
    _labelsByEventId.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByPubkey.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByHash.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByAddressableId.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
  }

  /// Canonical form of a labeler identity: lowercase hex, no surrounding
  /// whitespace.
  ///
  /// NIP-05 mandates lowercase hex and event authors arrive lowercase on the
  /// wire, so canonicalizing at the two points that produce an identity keeps
  /// [_divineModerationPubkey], [_subscribedLabelers] and the pin comparison on
  /// one form. Without it a non-lowercase answer would read as identical to the
  /// pin yet fail to match the labeler's own events in the subscription filter.
  static String _normalizedPubkey(String pubkey) => pubkey.trim().toLowerCase();

  /// Resolve the Divine moderation pubkey via cached value or NIP-05 lookup.
  ///
  /// Strategy: SharedPreferences cache (24h TTL) → NIP-05 → fallback constant.
  /// Every path returns a [_normalizedPubkey].
  Future<String> _resolveModerationPubkey(SharedPreferences prefs) async {
    // Check cached resolution
    final cachedPubkey = _normalizedPubkey(
      prefs.getString(_resolvedPubkeyKey) ?? '',
    );
    final cachedAtStr = prefs.getString(_resolvedAtKey);
    if (cachedPubkey.isNotEmpty && cachedAtStr != null) {
      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _resolvedPubkeyTtl) {
        return cachedPubkey;
      }
    }

    // Resolve via NIP-05
    try {
      final resolved = await Nip05Validor.getPubkey(divineModerationNip05);
      final normalized = _normalizedPubkey(resolved ?? '');
      if (normalized.isNotEmpty) {
        await prefs.setString(_resolvedPubkeyKey, normalized);
        await prefs.setString(_resolvedAtKey, DateTime.now().toIso8601String());
        Log.info(
          'Resolved moderation pubkey via NIP-05: $normalized',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return normalized;
      }
    } catch (e) {
      Log.warning(
        'NIP-05 resolution failed for $divineModerationNip05: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }

    // Use stale cache if available, otherwise fallback
    if (cachedPubkey.isNotEmpty) {
      return cachedPubkey;
    }
    return fallbackModerationPubkeyHex;
  }

  String _cachedModerationPubkey(SharedPreferences prefs) {
    final cachedPubkey = _normalizedPubkey(
      prefs.getString(_resolvedPubkeyKey) ?? '',
    );
    if (cachedPubkey.isNotEmpty) {
      return cachedPubkey;
    }
    return fallbackModerationPubkeyHex;
  }

  /// Adopt [pubkey] as the moderation labeler identity.
  ///
  /// Every path that settles on an identity funnels through here so the pin
  /// check cannot be bypassed by adding a new resolution source. [pubkey] is
  /// expected canonical — both producers return a [_normalizedPubkey].
  void _adoptModerationPubkey(String pubkey) {
    _divineModerationPubkey = pubkey;
    _warnIfPinMismatch(pubkey);
  }

  /// Advisory only: NIP-05 stays authoritative for the labeler identity
  /// (#4948 tier 1), so a divergence from the shipped pin is logged, never
  /// overridden. Without this, a hostile repoint of [divineModerationNip05] is
  /// indistinguishable from an intended rotation in the logs. Fires once per
  /// adoption, so a steady divergence costs one line per session rather than
  /// one per read.
  ///
  /// Both sides are canonical here — [adoptedPubkey] via [_normalizedPubkey]
  /// and the pin as a lowercase constant — so a case-only variant of the pin
  /// stays silent rather than crying wolf.
  void _warnIfPinMismatch(String adoptedPubkey) {
    if (adoptedPubkey == fallbackModerationPubkeyHex) {
      return;
    }
    Log.warning(
      'Moderation pubkey diverges from the key pinned in this build: '
      'adopted $adoptedPubkey, pinned $fallbackModerationPubkeyHex. '
      'Expected after an intended rotation; otherwise investigate '
      '$divineModerationNip05 for an unauthorized repoint.',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
  }

  Future<void> _refreshModerationPubkey() async {
    final previousPubkey = _divineModerationPubkey;
    final resolvedPubkey = await _resolveModerationPubkey(_prefs);
    if (resolvedPubkey == previousPubkey) return;

    _adoptModerationPubkey(resolvedPubkey);
    _subscribedLabelers.remove(previousPubkey);
    _subscribedLabelers.add(resolvedPubkey);
    await _saveSubscribedLabelers();
    await _unloadLabeler(previousPubkey);

    Log.info(
      'Updated moderation labeler from $previousPubkey to $resolvedPubkey',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
  }

  /// Migrate retired moderation pubkeys out of stored subscriptions.
  ///
  /// Existing users may have a pre-rotation pubkey persisted. Swaps every one
  /// still subscribed for the current resolved pubkey so they follow the right
  /// labeler. Idempotent — runs on every init.
  Future<void> _migrateLegacyPubkey() async {
    final retired = kLegacyModerationPubkeys
        .where(_subscribedLabelers.contains)
        .toList();
    if (retired.isEmpty) return;

    _subscribedLabelers.removeAll(retired);
    _subscribedLabelers.add(_divineModerationPubkey);
    await _saveSubscribedLabelers();

    for (final pubkey in retired) {
      // Clean up any labels fetched from the old key
      _removeLabelsForLabeler(pubkey);
      _loadedLabelers.remove(pubkey);
    }

    Log.info(
      'Migrated moderation labeler from retired pubkey(s) '
      '${retired.join(', ')} to $_divineModerationPubkey',
      name: 'ModerationLabelService',
      category: LogCategory.system,
    );
  }

  /// Clean up subscriptions.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}

/// Parsed metadata from the 4th element of an `l` tag.
class _LabelMetadata {
  const _LabelMetadata({this.confidence, this.source, this.isVerified = false});

  final double? confidence;
  final String? source;
  final bool isVerified;
}

class _PendingModerationLabel {
  const _PendingModerationLabel({
    required this.value,
    required this.namespace,
    required this.metadata,
  });

  final String value;
  final String? namespace;
  final _LabelMetadata? metadata;

  ModerationLabel toModerationLabel({
    required String labelerPubkey,
    String? targetEventId,
    String? targetAddressableId,
    String? targetPubkey,
  }) => ModerationLabel(
    labelerPubkey: labelerPubkey,
    labelValue: value,
    targetEventId: targetEventId,
    targetAddressableId: targetAddressableId,
    targetPubkey: targetPubkey,
    confidence: metadata?.confidence,
    source: metadata?.source,
    isVerified: metadata?.isVerified ?? false,
  );
}
