// ABOUTME: Content moderation service with NIP-51 mute list support
// ABOUTME: Manages client-side content filtering while respecting decentralized principles

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr/nostr.dart';
import 'nostr_service_interface.dart';

/// Reasons for content filtering/reporting
enum ContentFilterReason {
  spam('Spam or unwanted content'),
  harassment('Harassment or bullying'), 
  violence('Violence or threats'),
  sexualContent('Sexual or adult content'),
  copyright('Copyright violation'),
  falseInformation('Misinformation'),
  csam('Child safety concern'),
  other('Other violation');

  const ContentFilterReason(this.description);
  final String description;
}

/// Content severity levels for filtering
enum ContentSeverity {
  info,     // Informational only
  warning,  // Show warning but allow viewing
  hide,     // Hide by default, show if requested
  block     // Completely block content
}

/// Mute list entry representing filtered content
class MuteListEntry {
  final String type; // 'pubkey', 'event', 'keyword', 'content-type'
  final String value;
  final ContentFilterReason reason;
  final ContentSeverity severity;
  final DateTime createdAt;
  final String? note;

  const MuteListEntry({
    required this.type,
    required this.value,
    required this.reason,
    required this.severity,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'reason': reason.name,
      'severity': severity.name,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  static MuteListEntry fromJson(Map<String, dynamic> json) {
    return MuteListEntry(
      type: json['type'],
      value: json['value'],
      reason: ContentFilterReason.values.firstWhere(
        (r) => r.name == json['reason'],
        orElse: () => ContentFilterReason.other,
      ),
      severity: ContentSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => ContentSeverity.hide,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      note: json['note'],
    );
  }

  /// Convert to NIP-51 list entry tag format
  List<String> toNIP51Tag() {
    final tag = [type, value];
    if (note != null) tag.add(note!);
    return tag;
  }
}

/// Content moderation result
class ModerationResult {
  final bool shouldFilter;
  final ContentSeverity severity;
  final List<ContentFilterReason> reasons;
  final String? warningMessage;
  final List<MuteListEntry> matchingEntries;

  const ModerationResult({
    required this.shouldFilter,
    required this.severity,
    required this.reasons,
    this.warningMessage,
    required this.matchingEntries,
  });

  static const ModerationResult clean = ModerationResult(
    shouldFilter: false,
    severity: ContentSeverity.info,
    reasons: [],
    matchingEntries: [],
  );
}

/// Content moderation service managing mute lists and filtering
class ContentModerationService extends ChangeNotifier {
  final INostrService _nostrService;
  final SharedPreferences _prefs;
  
  // Default NostrVine moderation list
  static const String defaultMuteListId = 'nostrvine-default-mutes-v1';
  static const String defaultMuteListPubkey = 'npub1nostrvinemoderation'; // Placeholder
  
  // Local storage keys
  static const String _localMuteListKey = 'content_moderation_local_mutes';
  static const String _subscribedListsKey = 'content_moderation_subscribed_lists';
  static const String _settingsKey = 'content_moderation_settings';
  
  // Mute lists
  final Map<String, List<MuteListEntry>> _muteLists = {};
  List<String> _subscribedLists = [];
  
  // Settings
  bool _enableDefaultModeration = true;
  bool _enableCustomMuteLists = true;
  bool _showContentWarnings = true;
  ContentSeverity _autoHideLevel = ContentSeverity.hide;
  
  ContentModerationService({
    required INostrService nostrService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _prefs = prefs {
    _loadSettings();
    _loadLocalMuteList();
    _loadSubscribedLists();
  }

  // Getters
  bool get enableDefaultModeration => _enableDefaultModeration;
  bool get enableCustomMuteLists => _enableCustomMuteLists;
  bool get showContentWarnings => _showContentWarnings;
  ContentSeverity get autoHideLevel => _autoHideLevel;
  List<String> get subscribedLists => List.unmodifiable(_subscribedLists);
  
  /// Initialize content moderation
  Future<void> initialize() async {
    try {
      // Subscribe to default NostrVine moderation list
      if (_enableDefaultModeration) {
        await _subscribeToDefaultList();
      }
      
      // Subscribe to user's custom mute lists
      if (_enableCustomMuteLists) {
        for (final listId in _subscribedLists) {
          await _subscribeToMuteList(listId);
        }
      }
      
      debugPrint('✅ Content moderation initialized with ${_muteLists.length} lists');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize content moderation: $e');
    }
  }

  /// Check if content should be filtered
  ModerationResult checkContent(Event event) {
    if (!_enableDefaultModeration && !_enableCustomMuteLists) {
      return ModerationResult.clean;
    }

    final matchingEntries = <MuteListEntry>[];
    final reasons = <ContentFilterReason>{};
    ContentSeverity maxSeverity = ContentSeverity.info;

    // Check against all active mute lists
    for (final entries in _muteLists.values) {
      for (final entry in entries) {
        if (_doesEntryMatch(entry, event)) {
          matchingEntries.add(entry);
          reasons.add(entry.reason);
          if (entry.severity.index > maxSeverity.index) {
            maxSeverity = entry.severity;
          }
        }
      }
    }

    final shouldFilter = matchingEntries.isNotEmpty && 
                        maxSeverity.index >= _autoHideLevel.index;

    String? warningMessage;
    if (matchingEntries.isNotEmpty) {
      final primaryReason = reasons.first;
      warningMessage = _buildWarningMessage(primaryReason, matchingEntries.length);
    }

    return ModerationResult(
      shouldFilter: shouldFilter,
      severity: maxSeverity,
      reasons: reasons.toList(),
      warningMessage: warningMessage,
      matchingEntries: matchingEntries,
    );
  }

  /// Add entry to local mute list
  Future<void> addToMuteList({
    required String type,
    required String value,
    required ContentFilterReason reason,
    ContentSeverity severity = ContentSeverity.hide,
    String? note,
  }) async {
    final entry = MuteListEntry(
      type: type,
      value: value,
      reason: reason,
      severity: severity,
      createdAt: DateTime.now(),
      note: note,
    );

    // Add to local list
    final localList = _muteLists['local'] ?? [];
    localList.add(entry);
    _muteLists['local'] = localList;

    await _saveLocalMuteList();
    notifyListeners();

    debugPrint('🚫 Added to mute list: $type:$value (${reason.name})');
  }

  /// Remove entry from local mute list
  Future<void> removeFromMuteList(String type, String value) async {
    final localList = _muteLists['local'];
    if (localList != null) {
      localList.removeWhere((entry) => 
        entry.type == type && entry.value == value);
      await _saveLocalMuteList();
      notifyListeners();
    }
  }

  /// Block a user (add pubkey to mute list)
  Future<void> blockUser(String pubkey, {String? reason}) async {
    await addToMuteList(
      type: 'pubkey',
      value: pubkey,
      reason: ContentFilterReason.harassment,
      severity: ContentSeverity.block,
      note: reason,
    );
  }

  /// Mute a keyword
  Future<void> muteKeyword(String keyword, ContentSeverity severity) async {
    await addToMuteList(
      type: 'keyword',
      value: keyword.toLowerCase(),
      reason: ContentFilterReason.spam,
      severity: severity,
    );
  }

  /// Subscribe to external mute list
  Future<void> subscribeToMuteList(String listId) async {
    if (_subscribedLists.contains(listId)) return;

    try {
      _subscribedLists.add(listId);
      await _subscribeToMuteList(listId);
      await _saveSubscribedLists();
      notifyListeners();
      
      debugPrint('📝 Subscribed to mute list: $listId');
    } catch (e) {
      _subscribedLists.remove(listId);
      debugPrint('⚠️ Failed to subscribe to mute list $listId: $e');
      rethrow;
    }
  }

  /// Unsubscribe from mute list
  Future<void> unsubscribeFromMuteList(String listId) async {
    _subscribedLists.remove(listId);
    _muteLists.remove(listId);
    await _saveSubscribedLists();
    notifyListeners();
  }

  /// Update moderation settings
  Future<void> updateSettings({
    bool? enableDefaultModeration,
    bool? enableCustomMuteLists,
    bool? showContentWarnings,
    ContentSeverity? autoHideLevel,
  }) async {
    _enableDefaultModeration = enableDefaultModeration ?? _enableDefaultModeration;
    _enableCustomMuteLists = enableCustomMuteLists ?? _enableCustomMuteLists;
    _showContentWarnings = showContentWarnings ?? _showContentWarnings;
    _autoHideLevel = autoHideLevel ?? _autoHideLevel;

    await _saveSettings();
    notifyListeners();
  }

  /// Get moderation statistics
  Map<String, dynamic> getModerationStats() {
    int totalEntries = 0;
    int pubkeyBlocks = 0;
    int keywordMutes = 0;
    
    for (final entries in _muteLists.values) {
      totalEntries += entries.length;
      pubkeyBlocks += entries.where((e) => e.type == 'pubkey').length;
      keywordMutes += entries.where((e) => e.type == 'keyword').length;
    }

    return {
      'totalMuteLists': _muteLists.length,
      'totalEntries': totalEntries,
      'pubkeyBlocks': pubkeyBlocks,
      'keywordMutes': keywordMutes,
      'subscribedLists': _subscribedLists.length,
    };
  }

  /// Subscribe to default NostrVine moderation list
  Future<void> _subscribeToDefaultList() async {
    try {
      // This would subscribe to official NostrVine moderation list
      // For now, create a basic default list
      final defaultEntries = [
        MuteListEntry(
          type: 'keyword',
          value: 'spam',
          reason: ContentFilterReason.spam,
          severity: ContentSeverity.hide,
          createdAt: DateTime.now(),
          note: 'Default spam filtering',
        ),
        MuteListEntry(
          type: 'keyword', 
          value: 'nsfw',
          reason: ContentFilterReason.sexualContent,
          severity: ContentSeverity.warning,
          createdAt: DateTime.now(),
          note: 'Adult content warning',
        ),
      ];
      
      _muteLists['default'] = defaultEntries;
      debugPrint('📋 Loaded default moderation list');
    } catch (e) {
      debugPrint('⚠️ Failed to load default moderation list: $e');
    }
  }

  /// Subscribe to external mute list via Nostr
  Future<void> _subscribeToMuteList(String listId) async {
    try {
      // TODO: Implement NIP-51 list subscription
      // This would fetch the mute list from Nostr and parse entries
      debugPrint('📡 Subscribing to mute list: $listId');
      
      // Placeholder implementation
      _muteLists[listId] = [];
    } catch (e) {
      debugPrint('⚠️ Failed to subscribe to mute list $listId: $e');
      rethrow;
    }
  }

  /// Check if mute list entry matches event
  bool _doesEntryMatch(MuteListEntry entry, Event event) {
    switch (entry.type) {
      case 'pubkey':
        return event.pubkey == entry.value;
      case 'event':
        return event.id == entry.value;
      case 'keyword':
        return event.content.toLowerCase().contains(entry.value);
      case 'content-type':
        // Check event tags for content type indicators
        return event.tags.any((tag) => 
          tag.length > 1 && 
          tag[0] == 'm' && 
          tag[1].startsWith(entry.value));
      default:
        return false;
    }
  }

  /// Build warning message for filtered content
  String _buildWarningMessage(ContentFilterReason reason, int matchCount) {
    final String baseMessage;
    switch (reason) {
      case ContentFilterReason.spam:
        baseMessage = 'This content may be spam';
        break;
      case ContentFilterReason.harassment:
        baseMessage = 'This content may contain harassment';
        break;
      case ContentFilterReason.violence:
        baseMessage = 'This content may contain violence';
        break;
      case ContentFilterReason.sexualContent:
        baseMessage = 'This content may be sensitive';
        break;
      case ContentFilterReason.copyright:
        baseMessage = 'This content may violate copyright';
        break;
      case ContentFilterReason.falseInformation:
        baseMessage = 'This content may contain misinformation';
        break;
      case ContentFilterReason.csam:
        baseMessage = 'This content violates child safety policies';
        break;
      case ContentFilterReason.other:
        baseMessage = 'This content may violate community guidelines';
        break;
    }

    if (matchCount > 1) {
      return '$baseMessage (matched $matchCount filters)';
    }
    return baseMessage;
  }

  /// Load settings from storage
  void _loadSettings() {
    final settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
        _enableDefaultModeration = settings['enableDefaultModeration'] ?? true;
        _enableCustomMuteLists = settings['enableCustomMuteLists'] ?? true;
        _showContentWarnings = settings['showContentWarnings'] ?? true;
        _autoHideLevel = ContentSeverity.values.firstWhere(
          (s) => s.name == settings['autoHideLevel'],
          orElse: () => ContentSeverity.hide,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to load moderation settings: $e');
      }
    }
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    final settings = {
      'enableDefaultModeration': _enableDefaultModeration,
      'enableCustomMuteLists': _enableCustomMuteLists,
      'showContentWarnings': _showContentWarnings,
      'autoHideLevel': _autoHideLevel.name,
    };
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  /// Load local mute list from storage
  void _loadLocalMuteList() {
    final muteListJson = _prefs.getString(_localMuteListKey);
    if (muteListJson != null) {
      try {
        final List<dynamic> entriesJson = jsonDecode(muteListJson);
        final entries = entriesJson
            .map((json) => MuteListEntry.fromJson(json))
            .toList();
        _muteLists['local'] = entries;
      } catch (e) {
        debugPrint('⚠️ Failed to load local mute list: $e');
      }
    }
  }

  /// Save local mute list to storage
  Future<void> _saveLocalMuteList() async {
    final localList = _muteLists['local'] ?? [];
    final entriesJson = localList.map((entry) => entry.toJson()).toList();
    await _prefs.setString(_localMuteListKey, jsonEncode(entriesJson));
  }

  /// Load subscribed lists from storage
  void _loadSubscribedLists() {
    final listsJson = _prefs.getString(_subscribedListsKey);
    if (listsJson != null) {
      try {
        _subscribedLists = List<String>.from(jsonDecode(listsJson));
      } catch (e) {
        debugPrint('⚠️ Failed to load subscribed lists: $e');
      }
    }
  }

  /// Save subscribed lists to storage
  Future<void> _saveSubscribedLists() async {
    await _prefs.setString(_subscribedListsKey, jsonEncode(_subscribedLists));
  }

  @override
  void dispose() {
    // Clean up any active subscriptions
    super.dispose();
  }
}