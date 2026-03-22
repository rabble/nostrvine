// ABOUTME: Service for muting DM conversation notifications.
// ABOUTME: Persists muted conversation IDs to SharedPreferences.

import 'dart:convert';

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for muted conversations.
const _mutedConversationsKey = 'muted_conversations';

/// Service for managing muted DM conversations.
///
/// Muting silences push notifications for a conversation. The conversation
/// remains visible in the inbox. Mute state is local-only (not published
/// to Nostr).
class ConversationMuteService {
  ConversationMuteService({SharedPreferences? prefs}) : _prefs = prefs {
    _loadMutedConversations();
  }

  final SharedPreferences? _prefs;
  final Set<String> _mutedConversationIds = {};

  /// Whether the conversation is currently muted.
  bool isMuted(String conversationId) =>
      _mutedConversationIds.contains(conversationId);

  /// Toggle mute state for a conversation.
  ///
  /// Returns `true` if the conversation is now muted, `false` if unmuted.
  Future<bool> toggleMute(String conversationId) async {
    final nowMuted = !_mutedConversationIds.contains(conversationId);
    if (nowMuted) {
      _mutedConversationIds.add(conversationId);
    } else {
      _mutedConversationIds.remove(conversationId);
    }
    await _save();

    Log.debug(
      '${nowMuted ? "Muted" : "Unmuted"} conversation: $conversationId',
      name: 'ConversationMuteService',
      category: LogCategory.system,
    );
    return nowMuted;
  }

  void _loadMutedConversations() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_mutedConversationsKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _mutedConversationIds.addAll(list);
    } catch (e) {
      Log.error(
        'Failed to load muted conversations: $e',
        name: 'ConversationMuteService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_mutedConversationIds.toList());
      await prefs.setString(_mutedConversationsKey, json);
    } catch (e) {
      Log.error(
        'Failed to persist muted conversations: $e',
        name: 'ConversationMuteService',
        category: LogCategory.system,
      );
    }
  }
}
