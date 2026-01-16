// ABOUTME: Navigation extension helpers for clean GoRouter call-sites
// ABOUTME: Provides goHome/goExplore/goNotifications/goProfile/pushCamera/pushSettings (hashtag available via goHashtag)

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'route_utils.dart';

extension NavX on BuildContext {
  // Tab bases
  void goHome([int index = 0]) =>
      go(buildRoute(RouteContext(type: RouteType.home, videoIndex: index)));

  void goExplore([int? index]) =>
      go(buildRoute(RouteContext(type: RouteType.explore, videoIndex: index)));

  void goNotifications([int index = 0]) => go(
    buildRoute(RouteContext(type: RouteType.notifications, videoIndex: index)),
  );

  void goHashtag(String tag, [int? index]) => go(
    buildRoute(
      RouteContext(type: RouteType.hashtag, hashtag: tag, videoIndex: index),
    ),
  );

  /// Navigate to liked videos feed at optional index
  void goLikedVideos([int? index]) => go(
    buildRoute(RouteContext(type: RouteType.likedVideos, videoIndex: index)),
  );

  void goMyProfile() => goProfile('me');

  // TODO(548): Move all of the "me" logic into the router or the profile page
  void goProfile(String identifier, [int index = 0]) {
    debugPrint('🧭 goProfile called: identifier=$identifier, index=$index');

    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't navigate
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    final route = buildRoute(
      RouteContext(type: RouteType.profile, npub: npub, videoIndex: index),
    );
    debugPrint('🧭 goProfile: navigating to route=$route (videoIndex=$index)');
    go(route);
  }

  /// Navigate to profile in grid mode (no video playing)
  void goProfileGrid(String identifier) {
    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't navigate
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    go(
      buildRoute(
        RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: null, // Grid mode - no active video
        ),
      ),
    );
  }

  void pushProfile(String identifier, [int index = 0]) {
    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't push
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    push(
      buildRoute(
        RouteContext(type: RouteType.profile, npub: npub, videoIndex: index),
      ),
    );
  }

  /// Push profile in grid mode (no video playing) - use for other users' profiles
  void pushProfileGrid(String identifier) {
    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't push
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    push(
      buildRoute(
        RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: null, // Grid mode - no active video
        ),
      ),
    );
  }

  /// Navigate to profile grid, replacing navigation stack - use when navigating from fullscreen
  /// Uses `go` instead of `pushReplacement` to properly handle shell route transitions
  ///
  /// TODO(navigation): This is a temporary fix. In the long run, viewing other users' profiles
  /// should also be fullscreen (no bottom nav) similar to the video feed. Consider creating
  /// a FullscreenProfileScreen that can be pushed from fullscreen video feed.
  void goToProfileGridFromFullscreen(String identifier) {
    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't navigate
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    // Use `go` for declarative navigation - this properly handles
    // transitioning from non-shell routes to shell routes
    go(
      buildRoute(
        RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: null, // Grid mode - no active video
        ),
      ),
    );
  }

  void goSearch([String? searchTerm, int? index]) => go(
    buildRoute(
      RouteContext(
        type: RouteType.search,
        searchTerm: searchTerm,
        videoIndex: index,
      ),
    ),
  );

  // Optional pushes (non-tab routes)
  Future<void> pushCamera() => push('/camera');
  Future<void> pushSettings() => push('/settings');
  Future<void> pushComments(VideoEvent video) =>
      CommentsScreen.show(this, video);
  Future<void> pushFollowing(String pubkey, {String? displayName}) =>
      push('/following/$pubkey', extra: displayName);
  Future<void> pushFollowers(String pubkey, {String? displayName}) =>
      push('/followers/$pubkey', extra: displayName);

  /// Push fullscreen video feed (no bottom nav)
  ///
  /// Pass a [VideoFeedSource] to determine how videos are loaded:
  /// - [ProfileFeedSource] - Watches profileFeedProvider for reactive updates
  /// - [StaticFeedSource] - Uses a static list (no reactive updates)
  Future<void> pushVideoFeed({
    required VideoFeedSource source,
    required int initialIndex,
    String? contextTitle,
  }) => push(
    '/video-feed',
    extra: FullscreenVideoFeedArgs(
      source: source,
      initialIndex: initialIndex,
      contextTitle: contextTitle,
    ),
  );

  /// Push other user's profile screen (fullscreen, no bottom nav)
  ///
  /// Use this when navigating to another user's profile from video feeds,
  /// search results, comments, etc. For navigating to own profile, use
  /// goProfileGrid('me') instead.
  Future<void> pushOtherProfile(String identifier) async {
    // Handle 'me' special case - redirect to own profile tab instead
    if (identifier == 'me') {
      goProfileGrid('me');
      return;
    }

    // Get current user's hex for normalization if needed
    final container = ProviderScope.containerOf(this, listen: false);
    final authService = container.read(authServiceProvider);
    final currentUserHex = authService.currentPublicKeyHex;

    // Normalize any format (npub/nprofile/hex) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't push
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    await push('/profile-view/$npub');
  }

  /// Push curated list screen (NIP-51 kind 30005 video lists)
  Future<void> pushCuratedList({
    required String listId,
    required String listName,
    List<String>? videoIds,
    String? authorPubkey,
  }) => push(
    '/list/${Uri.encodeComponent(listId)}',
    extra: CuratedListRouteExtra(
      listName: listName,
      videoIds: videoIds,
      authorPubkey: authorPubkey,
    ),
  );

  /// Push discover lists screen (browse public NIP-51 kind 30005 lists)
  Future<void> pushDiscoverLists() => push('/discover-lists');
}
