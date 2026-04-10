// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';

import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Represents a user that can receive shared videos
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ShareableUser {
  const ShareableUser({
    required this.pubkey,
    this.displayName,
    this.picture,
    this.isFollowing = false,
    this.isFollower = false,
  });
  final String pubkey;
  final String? displayName;
  final String? picture;
  final bool isFollowing;
  final bool isFollower;
}

/// Structured share metadata for the platform share sheet.
///
/// Contains all the information needed to build a rich [ShareParams].
typedef ShareData = ({
  String shareUrl,
  String? title,
  String? thumbnailUrl,
});

/// Result of sharing operation
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ShareResult {
  const ShareResult({
    required this.success,
    this.error,
    this.messageEventId,
    this.conversationId,
  });
  final bool success;
  final String? error;
  final String? messageEventId;

  /// The DM conversation ID (NIP-17), used for "View Chat" navigation.
  final String? conversationId;

  static ShareResult createSuccess(
    String messageEventId, {
    String? conversationId,
  }) => ShareResult(
    success: true,
    messageEventId: messageEventId,
    conversationId: conversationId,
  );

  static ShareResult failure(String error) =>
      ShareResult(success: false, error: error);
}

/// Service for sharing videos with other users
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoSharingService {
  VideoSharingService({
    required NostrClient nostrService,
    required AuthService authService,
    required ProfileRepository profileRepository,
    DmRepository? dmRepository,
  }) : _nostrService = nostrService,
       _authService = authService,
       _profileRepository = profileRepository,
       _dmRepository = dmRepository;
  final NostrClient _nostrService;
  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final DmRepository? _dmRepository;

  final List<ShareableUser> _recentlySharedWith = [];
  final Map<String, DateTime> _shareHistory = {};

  // Getters
  List<ShareableUser> get recentlySharedWith =>
      List.unmodifiable(_recentlySharedWith);

  /// Share a video with a specific user via Nostr DM.
  ///
  /// When a [DmRepository] is available (user is authenticated with NIP-17),
  /// uses gift-wrapped encrypted DMs (kind 14/13/1059). Otherwise falls back
  /// to legacy NIP-04 encrypted DMs (kind 4).
  Future<ShareResult> shareVideoWithUser({
    required VideoEvent video,
    required String recipientPubkey,
    String? personalMessage,
  }) async {
    try {
      Log.debug(
        'Sharing video with user: $recipientPubkey',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );

      if (!_authService.isAuthenticated) {
        return ShareResult.failure('User not authenticated');
      }

      final dmContent = _createShareMessage(video, personalMessage);

      // Prefer NIP-17 when DmRepository is available
      if (_dmRepository != null) {
        return _shareViaNip17(
          recipientPubkey: recipientPubkey,
          content: dmContent,
        );
      }

      // Fallback to NIP-04 (legacy)
      return _shareViaNip04(
        video: video,
        recipientPubkey: recipientPubkey,
        content: dmContent,
      );
    } catch (e) {
      Log.error(
        'Error sharing video: $e',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return ShareResult.failure('Error sharing video: $e');
    }
  }

  Future<ShareResult> _shareViaNip17({
    required String recipientPubkey,
    required String content,
  }) async {
    final dmRepo = _dmRepository!;
    final result = await dmRepo.sendMessage(
      recipientPubkey: recipientPubkey,
      content: content,
    );

    if (result.success) {
      _shareHistory[recipientPubkey] = DateTime.now();
      await _updateRecentlySharedWith(recipientPubkey);

      final participants = [dmRepo.userPubkey, recipientPubkey]..sort();
      final conversationId = DmRepository.computeConversationId(participants);

      Log.info(
        'Video shared via NIP-17: ${result.messageEventId}',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );

      return ShareResult.createSuccess(
        result.messageEventId!,
        conversationId: conversationId,
      );
    }

    return ShareResult.failure(
      result.error ?? 'Failed to send NIP-17 message',
    );
  }

  Future<ShareResult> _shareViaNip04({
    required VideoEvent video,
    required String recipientPubkey,
    required String content,
  }) async {
    final tags = <List<String>>[
      ['p', recipientPubkey],
      ['client', 'diVine'],
      ['e', video.id],
    ];

    final event = await _authService.createAndSignEvent(
      kind: 4,
      content: content,
      tags: tags,
    );

    if (event == null) {
      return ShareResult.failure('Failed to create share message');
    }

    final sentEvent = await _nostrService.publishEvent(event);

    if (sentEvent != null) {
      _shareHistory[recipientPubkey] = DateTime.now();
      await _updateRecentlySharedWith(recipientPubkey);

      Log.info(
        'Video shared via NIP-04: ${event.id}',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );

      return ShareResult.createSuccess(event.id);
    }

    return ShareResult.failure('Failed to publish share message');
  }

  /// Share video to multiple users at once
  Future<Map<String, ShareResult>> shareVideoWithMultipleUsers({
    required VideoEvent video,
    required List<String> recipientPubkeys,
    String? personalMessage,
  }) async {
    final results = <String, ShareResult>{};

    for (final pubkey in recipientPubkeys) {
      final result = await shareVideoWithUser(
        video: video,
        recipientPubkey: pubkey,
        personalMessage: personalMessage,
      );
      results[pubkey] = result;
    }

    return results;
  }

  /// Get shareable users (followers, following, recent contacts)
  Future<List<ShareableUser>> getShareableUsers({int limit = 20}) async {
    try {
      final shareableUsers = <ShareableUser>[];

      // Add recently shared with users first
      shareableUsers.addAll(_recentlySharedWith.take(5));

      // TODO: Add followers and following when social service integration is complete
      // For now, return recent users

      Log.info(
        'Found ${shareableUsers.length} shareable users',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return shareableUsers.take(limit).toList();
    } catch (e) {
      Log.error(
        'Error getting shareable users: $e',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Search for users to share with (by display name or pubkey)
  Future<List<ShareableUser>> searchUsersToShareWith(String query) async {
    try {
      // TODO: Implement user search when user directory service is available
      // For now, check if query looks like a pubkey and create a basic user

      if (query.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(query)) {
        // Looks like a hex pubkey
        final profile = await _profileRepository.fetchFreshProfile(
          pubkey: query,
        );
        return [
          ShareableUser(
            pubkey: query,
            displayName: profile?.displayName,
            picture: profile?.picture,
          ),
        ];
      }

      Log.debug(
        'User search not yet implemented for: $query',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return [];
    } catch (e) {
      Log.error(
        'Error searching users: $e',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Generate external share URL for the video.
  ///
  /// Uses [VideoEvent.stableId] (d-tag) for addressable events so the URL
  /// remains valid even if the user edits the video metadata.
  ///
  /// Requires funnelcake API to support d-tag lookups on /api/videos/{id}.
  String generateShareUrl(VideoEvent video) {
    const baseUrl = 'https://divine.video';
    return '$baseUrl/video/${video.stableId}';
  }

  /// Generate share text for external sharing (social media, etc.)
  ///
  /// Returns only the share URL so users can add their own context.
  String generateShareText(VideoEvent video) {
    return generateShareUrl(video);
  }

  /// Generate structured share metadata for the platform share sheet.
  ///
  /// Returns a [ShareData] record containing the share URL, video title,
  /// and thumbnail URL so callers can build rich [ShareParams] with an
  /// attached image file.
  ShareData generateShareData(VideoEvent video) {
    return (
      shareUrl: generateShareUrl(video),
      title: video.title,
      thumbnailUrl: video.effectiveThumbnailUrl,
    );
  }

  /// Check if user has been shared with recently
  bool hasSharedWithRecently(String pubkey) {
    final lastShared = _shareHistory[pubkey];
    if (lastShared == null) return false;

    final daysSinceShared = DateTime.now().difference(lastShared).inDays;
    return daysSinceShared < 7; // Consider "recent" as within 7 days
  }

  /// Get sharing statistics
  Map<String, dynamic> getSharingStats() {
    final totalShares = _shareHistory.length;
    final recentShares = _shareHistory.values
        .where((date) => DateTime.now().difference(date).inDays <= 30)
        .length;

    return {
      'totalShares': totalShares,
      'recentShares': recentShares,
      'uniqueRecipients': _shareHistory.keys.length,
      'averageSharesPerMonth': recentShares, // Simplified calculation
    };
  }

  /// Create the message content for sharing a video.
  ///
  /// Uses the stable web link (`divine.video/video/{stableId}`) instead of
  /// the raw CDN/blossom URL so the recipient sees a clean, shareable link
  /// that can be opened in a browser or deep-linked back into the app.
  String _createShareMessage(VideoEvent video, String? personalMessage) {
    final buffer = StringBuffer();

    if (personalMessage != null && personalMessage.isNotEmpty) {
      buffer.writeln(personalMessage);
      buffer.writeln();
    }

    if (video.title != null && video.title!.isNotEmpty) {
      buffer.writeln('"${video.title}"');
      buffer.writeln();
    }

    buffer.writeln(generateShareUrl(video));

    return buffer.toString();
  }

  /// Update recently shared with list
  Future<void> _updateRecentlySharedWith(String pubkey) async {
    try {
      // Remove if already in list
      _recentlySharedWith.removeWhere((user) => user.pubkey == pubkey);

      // Fetch user profile for display
      final profile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );

      // Add to front of list
      _recentlySharedWith.insert(
        0,
        ShareableUser(
          pubkey: pubkey,
          displayName: profile?.displayName,
          picture: profile?.picture,
        ),
      );

      // Keep only recent 10 users
      if (_recentlySharedWith.length > 10) {
        _recentlySharedWith.removeRange(10, _recentlySharedWith.length);
      }
    } catch (e) {
      Log.error(
        'Failed to update recently shared with: $e',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
    }
  }

  /// Clear sharing history (for privacy)
  void clearSharingHistory() {
    _shareHistory.clear();
    _recentlySharedWith.clear();

    Log.debug(
      '🧹 Cleared sharing history',
      name: 'VideoSharingService',
      category: LogCategory.video,
    );
  }
}
