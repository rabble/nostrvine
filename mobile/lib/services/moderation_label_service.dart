// ABOUTME: Service for consuming Kind 1985 label events from labeler pubkeys
// ABOUTME: Caches labels in memory and checks content warnings for events

import 'dart:async';

import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A content-warning label applied by a labeler to a target event or pubkey.
class ModerationLabel {
  const ModerationLabel({
    required this.labelerPubkey,
    required this.labelValue,
    required this.targetEventId,
    this.targetPubkey,
  });

  /// Pubkey of the labeler who applied this label.
  final String labelerPubkey;

  /// The label value (e.g. "nudity", "sexual").
  final String labelValue;

  /// Target event ID this label applies to, if any.
  final String? targetEventId;

  /// Target pubkey this label applies to, if any.
  final String? targetPubkey;
}

/// Service for subscribing to Kind 1985 label events from labeler pubkeys.
///
/// Maintains an in-memory cache of labels keyed by target (event ID or pubkey).
/// Auto-subscribes to the Divine official labeler on init.
class ModerationLabelService {
  ModerationLabelService({
    required NostrClient nostrClient,
    required AuthService authService,
  }) : _nostrClient = nostrClient,
       _authService = authService;

  final NostrClient _nostrClient;
  // ignore: unused_field
  final AuthService _authService;

  /// SharedPreferences key for subscribed labeler pubkeys.
  static const String _subscribedLabelersKey = 'subscribed_labeler_pubkeys';

  /// Divine official moderation account pubkey (hex).
  static const String divineModerationPubkeyHex =
      '121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72';

  /// Labels keyed by target event ID.
  final Map<String, List<ModerationLabel>> _labelsByEventId = {};

  /// Labels keyed by target pubkey.
  final Map<String, List<ModerationLabel>> _labelsByPubkey = {};

  /// Currently subscribed labeler pubkeys.
  final Set<String> _subscribedLabelers = {};

  /// Active subscriptions.
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Get all subscribed labeler pubkeys.
  Set<String> get subscribedLabelers => Set.unmodifiable(_subscribedLabelers);

  /// Initialize by loading persisted labeler subscriptions and subscribing.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_subscribedLabelersKey);
      if (saved != null) {
        _subscribedLabelers.addAll(saved);
      }

      // Always subscribe to Divine labeler
      if (!_subscribedLabelers.contains(divineModerationPubkeyHex)) {
        _subscribedLabelers.add(divineModerationPubkeyHex);
      }

      // Subscribe to all labelers
      for (final pubkey in _subscribedLabelers) {
        await subscribeToLabeler(pubkey);
      }

      Log.info(
        'ModerationLabelService initialized with '
        '${_subscribedLabelers.length} labelers',
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
    if (_subscriptions.containsKey(pubkey)) return;

    try {
      final filter = Filter(
        authors: [pubkey],
        kinds: [1985], // NIP-32 label events
      );

      final events = await _nostrClient.queryEvents([filter]);

      for (final event in events) {
        _processLabelEvent(event);
      }

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
    if (pubkey == divineModerationPubkeyHex) return;

    _subscribedLabelers.remove(pubkey);
    await _subscriptions[pubkey]?.cancel();
    _subscriptions.remove(pubkey);
    await _saveSubscribedLabelers();

    // Remove labels from this labeler
    _labelsByEventId.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
    _labelsByPubkey.forEach((_, labels) {
      labels.removeWhere((l) => l.labelerPubkey == pubkey);
    });
  }

  /// Get content-warning labels for a specific event ID.
  List<ModerationLabel> getContentWarnings(String eventId) {
    return _labelsByEventId[eventId] ?? const [];
  }

  /// Get content-warning labels for a specific pubkey (account-level labels).
  List<ModerationLabel> getLabelsForPubkey(String pubkey) {
    return _labelsByPubkey[pubkey] ?? const [];
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
      String? targetPubkey;

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
            }
          case 'e':
            targetEventId = tagValue;
          case 'p':
            targetPubkey = tagValue;
        }
      }

      if (!isContentWarning || labelValue == null) return;

      final label = ModerationLabel(
        labelerPubkey: labelerPubkey,
        labelValue: labelValue,
        targetEventId: targetEventId,
        targetPubkey: targetPubkey,
      );

      if (targetEventId != null) {
        _labelsByEventId.putIfAbsent(targetEventId, () => []).add(label);
      }
      if (targetPubkey != null) {
        _labelsByPubkey.putIfAbsent(targetPubkey, () => []).add(label);
      }
    } catch (e) {
      Log.error(
        'Error processing label event: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Persist subscribed labeler pubkeys.
  Future<void> _saveSubscribedLabelers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
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

  /// Clean up subscriptions.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
