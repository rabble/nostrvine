// ABOUTME: Service for consuming Kind 1985 label events from labeler pubkeys
// ABOUTME: Caches labels in memory and checks content warnings for events

import 'dart:async';
import 'dart:convert';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';
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
  }) : _nostrClient = nostrClient,
       _authService = authService,
       _prefs = sharedPreferences;

  final NostrClient _nostrClient;
  // ignore: unused_field
  final AuthService _authService;
  final SharedPreferences _prefs;

  /// SharedPreferences key for subscribed labeler pubkeys.
  static const String _subscribedLabelersKey = 'subscribed_labeler_pubkeys';

  /// SharedPreferences key for using followed accounts as trusted labelers.
  static const String _followingModerationEnabledKey =
      'following_moderation_enabled';

  /// SharedPreferences key for the NIP-05 resolved moderation pubkey.
  static const String _resolvedPubkeyKey = 'divine_moderation_resolved_pubkey';

  /// SharedPreferences key for when the moderation pubkey was last resolved.
  static const String _resolvedAtKey = 'divine_moderation_resolved_at';

  /// NIP-05 address for the Divine moderation identity.
  static const String divineModerationNip05 = 'moderation@divine.video';

  /// Fallback pubkey when NIP-05 resolution fails.
  static const String fallbackModerationPubkeyHex =
      '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';

  /// Old pubkey — used only for one-time migration of stored subscriptions.
  static const String _legacyModerationPubkeyHex =
      '121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72';

  /// Cache TTL for NIP-05 resolved pubkey (24 hours).
  static const Duration _resolvedPubkeyTtl = Duration(hours: 24);

  /// Resolved Divine moderation pubkey (NIP-05 → cache → fallback).
  String _divineModerationPubkey = fallbackModerationPubkeyHex;

  /// The current Divine moderation pubkey (resolved via NIP-05 or fallback).
  String get divineModerationPubkeyHex => _divineModerationPubkey;

  /// Whether the Divine official labeler is currently subscribed.
  bool get isDivineLabelerSubscribed =>
      _subscribedLabelers.contains(_divineModerationPubkey);

  /// Subscribe to the Divine official labeler.
  Future<void> addDivineLabeler() => addLabeler(_divineModerationPubkey);

  /// Unsubscribe from the Divine official labeler (no-op by design —
  /// [removeLabeler] guards against removing the built-in labeler).
  Future<void> removeDivineLabeler() => removeLabeler(_divineModerationPubkey);

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

  /// Active subscriptions.
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Whether followed accounts should act as trusted labelers.
  bool _isFollowingModerationEnabled = false;

  /// Get all subscribed labeler pubkeys.
  Set<String> get subscribedLabelers => Set.unmodifiable(_subscribedLabelers);

  /// Whether followed accounts are enabled as trusted labelers.
  bool get isFollowingModerationEnabled => _isFollowingModerationEnabled;

  /// Initialize by loading persisted labeler subscriptions and subscribing.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Resolve Divine moderation pubkey (cache → NIP-05 → fallback)
      _divineModerationPubkey = await _resolveModerationPubkey(_prefs);

      final saved = _prefs.getStringList(_subscribedLabelersKey);
      if (saved != null) {
        _subscribedLabelers.addAll(saved);
      }
      _isFollowingModerationEnabled =
          _prefs.getBool(_followingModerationEnabledKey) ?? false;

      // Migrate legacy pubkey if present in stored subscriptions
      await _migrateLegacyPubkey(_prefs);

      // Always subscribe to Divine labeler
      if (!_subscribedLabelers.contains(_divineModerationPubkey)) {
        _subscribedLabelers.add(_divineModerationPubkey);
      }

      // Subscribe to all labelers
      for (final pubkey in _subscribedLabelers) {
        await subscribeToLabeler(pubkey);
      }

      Log.info(
        'ModerationLabelService initialized with '
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
    }
  }

  /// Subscribe to Kind 1985 events from a labeler pubkey.
  Future<void> subscribeToLabeler(String pubkey) async {
    if (_loadedLabelers.contains(pubkey)) return;

    try {
      final filter = Filter(
        authors: [pubkey],
        kinds: [1985], // NIP-32 label events
      );

      final events = await _nostrClient.queryEvents([filter]);

      for (final event in events) {
        _processLabelEvent(event);
      }

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
    _subscribedLabelers.add(pubkey);
    await _saveSubscribedLabelers();
    await subscribeToLabeler(pubkey);
  }

  /// Remove a labeler and clean up.
  Future<void> removeLabeler(String pubkey) async {
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
    _isFollowingModerationEnabled = enabled;
    await _saveFollowingModerationEnabled();
    await _syncFollowedLabelersInternal(
      enabled ? followedPubkeys : const <String>[],
    );
  }

  /// Sync the currently followed pubkeys that should act as trusted labelers.
  Future<void> syncFollowedLabelers(Iterable<String> followedPubkeys) async {
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

      // Check if this is a content-warning label
      bool isContentWarning = false;
      String? labelValue;
      String? targetEventId;
      String? targetAddressableId;
      String? targetPubkey;
      String? contentHash;
      double? confidence;
      String? source;
      bool isVerified = false;

      for (final tag in tags) {
        if (tag is! List || tag.length < 2) continue;
        final tagName = tag[0] as String;
        final tagValue = tag[1] as String;

        switch (tagName) {
          case 'L':
            if (tagValue == 'content-warning') {
              isContentWarning = true;
            }
          case 'l':
            if (tag.length > 2 && tag[2] == 'content-warning') {
              labelValue = tagValue;
              isContentWarning = true;

              // Parse optional 4th element as JSON metadata
              if (tag.length > 3 && tag[3] is String) {
                final parsed = _parseMetadata(tag[3] as String);
                if (parsed != null) {
                  confidence = parsed.confidence;
                  source = parsed.source;
                  isVerified = parsed.isVerified;
                }
              }
            }
          case 'e':
            targetEventId = tagValue;
          case 'a':
            targetAddressableId = tagValue;
          case 'p':
            targetPubkey = tagValue;
          case 'x':
            contentHash = tagValue;
        }
      }

      if (!isContentWarning || labelValue == null) return;

      final label = ModerationLabel(
        labelerPubkey: labelerPubkey,
        labelValue: labelValue,
        targetEventId: targetEventId,
        targetAddressableId: targetAddressableId,
        targetPubkey: targetPubkey,
        confidence: confidence,
        source: source,
        isVerified: isVerified,
      );

      if (targetEventId != null) {
        _labelsByEventId.putIfAbsent(targetEventId, () => []).add(label);
      }
      if (targetAddressableId != null) {
        _labelsByAddressableId
            .putIfAbsent(targetAddressableId, () => [])
            .add(label);
      }
      if (targetPubkey != null) {
        _labelsByPubkey.putIfAbsent(targetPubkey, () => []).add(label);
      }
      if (contentHash != null) {
        _labelsByHash.putIfAbsent(contentHash, () => []).add(label);
      }
    } catch (e) {
      Log.error(
        'Error processing label event: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
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
    final toAdd = normalized.difference(_followedLabelers);

    for (final pubkey in toRemove) {
      _followedLabelers.remove(pubkey);
      if (!_subscribedLabelers.contains(pubkey)) {
        await _unloadLabeler(pubkey);
      }
    }

    for (final pubkey in toAdd) {
      _followedLabelers.add(pubkey);
      if (!_subscribedLabelers.contains(pubkey)) {
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

  /// Resolve the Divine moderation pubkey via cached value or NIP-05 lookup.
  ///
  /// Strategy: SharedPreferences cache (24h TTL) → NIP-05 → fallback constant.
  Future<String> _resolveModerationPubkey(SharedPreferences prefs) async {
    // Check cached resolution
    final cachedPubkey = prefs.getString(_resolvedPubkeyKey);
    final cachedAtStr = prefs.getString(_resolvedAtKey);
    if (cachedPubkey != null &&
        cachedPubkey.isNotEmpty &&
        cachedAtStr != null) {
      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _resolvedPubkeyTtl) {
        return cachedPubkey;
      }
    }

    // Resolve via NIP-05
    try {
      final resolved = await Nip05Validor.getPubkey(divineModerationNip05);
      if (resolved != null && resolved.isNotEmpty) {
        await prefs.setString(_resolvedPubkeyKey, resolved);
        await prefs.setString(_resolvedAtKey, DateTime.now().toIso8601String());
        Log.info(
          'Resolved moderation pubkey via NIP-05: $resolved',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return resolved;
      }
    } catch (e) {
      Log.warning(
        'NIP-05 resolution failed for $divineModerationNip05: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }

    // Use stale cache if available, otherwise fallback
    if (cachedPubkey != null && cachedPubkey.isNotEmpty) {
      return cachedPubkey;
    }
    return fallbackModerationPubkeyHex;
  }

  /// Migrate the legacy moderation pubkey out of stored subscriptions.
  ///
  /// Existing users may have the old pubkey persisted. This swaps it for
  /// the current resolved pubkey so they subscribe to the right labeler.
  Future<void> _migrateLegacyPubkey(SharedPreferences prefs) async {
    if (!_subscribedLabelers.contains(_legacyModerationPubkeyHex)) return;

    _subscribedLabelers.remove(_legacyModerationPubkeyHex);
    _subscribedLabelers.add(_divineModerationPubkey);
    await _saveSubscribedLabelers();

    // Clean up any labels fetched from the old key
    _removeLabelsForLabeler(_legacyModerationPubkeyHex);
    _loadedLabelers.remove(_legacyModerationPubkeyHex);

    Log.info(
      'Migrated moderation labeler from legacy pubkey '
      '$_legacyModerationPubkeyHex to $_divineModerationPubkey',
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
