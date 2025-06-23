// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import '../models/video_event.dart';
import 'nostr_service_interface.dart';
import 'auth_service.dart';
import 'user_profile_service.dart';

/// Represents a user that can receive shared videos
class ShareableUser {
  final String pubkey;
  final String? displayName;
  final String? picture;
  final bool isFollowing;
  final bool isFollower;

  const ShareableUser({
    required this.pubkey,
    this.displayName,
    this.picture,
    this.isFollowing = false,
    this.isFollower = false,
  });
}

/// Result of sharing operation
class ShareResult {
  final bool success;
  final String? error;
  final String? messageEventId;

  const ShareResult({
    required this.success,
    this.error,
    this.messageEventId,
  });

  static ShareResult createSuccess(String messageEventId) => ShareResult(
    success: true,
    messageEventId: messageEventId,
  );

  static ShareResult failure(String error) => ShareResult(
    success: false,
    error: error,
  );
}

/// Service for sharing videos with other users
class VideoSharingService extends ChangeNotifier {
  final INostrService _nostrService;
  final AuthService _authService;
  final UserProfileService _userProfileService;

  final List<ShareableUser> _recentlySharedWith = [];
  final Map<String, DateTime> _shareHistory = {};

  VideoSharingService({
    required INostrService nostrService,
    required AuthService authService,
    required UserProfileService userProfileService,
  }) : _nostrService = nostrService,
       _authService = authService,
       _userProfileService = userProfileService;

  // Getters
  List<ShareableUser> get recentlySharedWith => List.unmodifiable(_recentlySharedWith);

  /// Share a video with a specific user via Nostr DM
  Future<ShareResult> shareVideoWithUser({
    required VideoEvent video,
    required String recipientPubkey,
    String? personalMessage,
  }) async {
    try {
      debugPrint('📤 Sharing video with user: ${recipientPubkey.substring(0, 8)}...');

      if (!_authService.isAuthenticated) {
        return ShareResult.failure('User not authenticated');
      }

      // Create encrypted DM with video reference
      final dmContent = _createShareMessage(video, personalMessage);
      
      // Create NIP-04 encrypted DM (kind 4)
      final tags = <List<String>>[
        ['p', recipientPubkey], // Recipient
        ['client', 'openvine'],
      ];

      // Add video reference as tag
      tags.add(['e', video.id]); // Reference to video event

      final event = await _authService.createAndSignEvent(
        kind: 4, // NIP-04 encrypted direct message
        content: dmContent,
        tags: tags,
      );

      if (event == null) {
        return ShareResult.failure('Failed to create share message');
      }

      // Broadcast the DM
      final result = await _nostrService.broadcastEvent(event);
      
      if (result.successCount > 0) {
        // Update sharing history
        _shareHistory[recipientPubkey] = DateTime.now();
        await _updateRecentlySharedWith(recipientPubkey);
        
        debugPrint('✅ Video shared successfully: ${event.id}');
        notifyListeners();
        return ShareResult.createSuccess(event.id);
      } else {
        return ShareResult.failure('Failed to broadcast share message');
      }

    } catch (e) {
      debugPrint('❌ Error sharing video: $e');
      return ShareResult.failure('Error sharing video: $e');
    }
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
      
      debugPrint('📋 Found ${shareableUsers.length} shareable users');
      return shareableUsers.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting shareable users: $e');
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
        final profile = await _userProfileService.fetchProfile(query);
        return [
          ShareableUser(
            pubkey: query,
            displayName: profile?.displayName,
            picture: profile?.picture,
          )
        ];
      }

      debugPrint('🔍 User search not yet implemented for: $query');
      return [];
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  /// Generate external share URL for the video
  String generateShareUrl(VideoEvent video) {
    // Create a shareable URL that opens the video in a web viewer
    final baseUrl = 'https://openvine.co';
    return '$baseUrl/watch/${video.id}';
  }

  /// Generate share text for external sharing (social media, etc.)
  String generateShareText(VideoEvent video) {
    final title = video.title ?? 'Check out this vine!';
    final url = generateShareUrl(video);
    
    String shareText = title;
    if (video.hashtags.isNotEmpty) {
      final hashtags = video.hashtags.map((tag) => '#$tag').join(' ');
      shareText += '\n\n$hashtags';
    }
    shareText += '\n\nWatch on OpenVine: $url';
    
    return shareText;
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

  /// Create the message content for sharing a video
  String _createShareMessage(VideoEvent video, String? personalMessage) {
    final buffer = StringBuffer();
    
    if (personalMessage != null && personalMessage.isNotEmpty) {
      buffer.writeln(personalMessage);
      buffer.writeln();
    }
    
    buffer.writeln('🎬 Check out this vine:');
    
    if (video.title != null && video.title!.isNotEmpty) {
      buffer.writeln('"${video.title}"');
    }
    
    if (video.videoUrl != null) {
      buffer.writeln();
      buffer.writeln(video.videoUrl);
    }
    
    if (video.hashtags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(video.hashtags.map((tag) => '#$tag').join(' '));
    }
    
    buffer.writeln();
    buffer.writeln('Shared via OpenVine 🍇');
    
    return buffer.toString();
  }

  /// Update recently shared with list
  Future<void> _updateRecentlySharedWith(String pubkey) async {
    try {
      // Remove if already in list
      _recentlySharedWith.removeWhere((user) => user.pubkey == pubkey);
      
      // Fetch user profile for display
      final profile = await _userProfileService.fetchProfile(pubkey);
      
      // Add to front of list
      _recentlySharedWith.insert(0, ShareableUser(
        pubkey: pubkey,
        displayName: profile?.displayName,
        picture: profile?.picture,
      ));
      
      // Keep only recent 10 users
      if (_recentlySharedWith.length > 10) {
        _recentlySharedWith.removeRange(10, _recentlySharedWith.length);
      }
      
    } catch (e) {
      debugPrint('⚠️ Failed to update recently shared with: $e');
    }
  }

  /// Clear sharing history (for privacy)
  void clearSharingHistory() {
    _shareHistory.clear();
    _recentlySharedWith.clear();
    notifyListeners();
    debugPrint('🧹 Cleared sharing history');
  }
}