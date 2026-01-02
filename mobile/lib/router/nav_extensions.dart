// ABOUTME: Navigation extension helpers for clean GoRouter call-sites
// ABOUTME: Provides goHome/goExplore/goNotifications/goProfile/pushCamera/pushSettings

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/followers/my_followers_screen.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

extension NavX on BuildContext {
  // Tab navigation - uses Screen path helper methods
  void goHome([int index = 0]) => go(HomeScreenRouter.pathForIndex(index));

  void goExplore([int? index]) => go(ExploreScreen.pathForIndex(index));

  void goNotifications([int index = 0]) =>
      go(NotificationsScreen.pathForIndex(index));

  void goHashtag(String tag, [int? index]) {
    final encodedTag = Uri.encodeComponent(tag);
    go(
      index != null
          ? HashtagScreenRouter.pathForTagWithIndex(encodedTag, index)
          : HashtagScreenRouter.pathForTag(encodedTag),
    );
  }

  void goMyProfile() => goProfileGrid('me');

  void goProfile(String identifier, [int index = 0]) {
    final npub = _resolveNpub(identifier);
    if (npub == null) return;
    go(ProfileScreenRouter.pathForNpubWithIndex(npub, index));
  }

  void goProfileGrid(String identifier) {
    final npub = _resolveNpub(identifier);
    if (npub == null) return;
    go(ProfileScreenRouter.pathForNpub(npub));
  }

  void pushProfile(String identifier, [int index = 0]) {
    final npub = _resolveNpub(identifier);
    if (npub == null) return;
    push(ProfileScreenRouter.pathForNpubWithIndex(npub, index));
  }

  void pushProfileGrid(String identifier) {
    final npub = _resolveNpub(identifier);
    if (npub == null) return;
    push(ProfileScreenRouter.pathForNpub(npub));
  }

  void goSearch([String? searchTerm, int? index]) {
    if (searchTerm == null && index == null) {
      go(SearchScreenPure.path);
    } else if (searchTerm != null && index == null) {
      final encodedTerm = Uri.encodeComponent(searchTerm);
      go(SearchScreenPure.pathForTerm(encodedTerm));
    } else if (searchTerm != null && index != null) {
      final encodedTerm = Uri.encodeComponent(searchTerm);
      go(SearchScreenPure.pathForTermWithIndex(encodedTerm, index));
    } else {
      // This case (index != null but searchTerm == null) shouldn't happen normally
      go('${SearchScreenPure.path}/$index');
    }
  }

  // Non-tab routes - uses Screen.path static getters
  Future<void> pushCamera() => push(UniversalCameraScreenPure.path);
  Future<void> pushSettings() => push(SettingsScreen.path);

  void pushComments(VideoEvent video) =>
      push(CommentsScreen.path.replaceFirst(':id', video.id));

  Future<void> pushFollowing(String pubkey, {String? displayName}) => push(
    MyFollowingScreen.path.replaceFirst(':pubkey', pubkey),
    extra: displayName,
  );

  Future<void> pushFollowers(String pubkey, {String? displayName}) => push(
    MyFollowersScreen.path.replaceFirst(':pubkey', pubkey),
    extra: displayName,
  );

  String? _resolveNpub(String identifier) {
    String? currentUserHex;
    if (identifier == 'me') {
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }
    return normalizeToNpub(identifier, currentUserHex: currentUserHex);
  }
}
