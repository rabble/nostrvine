// ABOUTME: Navigator keys for per-tab state preservation
// ABOUTME: Each tab has its own navigator key to maintain independent navigation stacks

import 'package:flutter/widgets.dart';

/// Navigator keys for per-tab state preservation in the app shell.
///
/// Each key maintains a separate navigation stack, allowing tabs to preserve
/// their state when switching between them.
class NavigatorKeys {
  /// Root navigator key for the entire app.
  static final root = GlobalKey<NavigatorState>(debugLabel: 'root');

  /// Home tab navigator key.
  static final home = GlobalKey<NavigatorState>(debugLabel: 'home');

  /// Explore tab navigator key for grid mode (no video index).
  static final exploreGrid = GlobalKey<NavigatorState>(
    debugLabel: 'explore-grid',
  );

  /// Explore tab navigator key for feed mode (with video index).
  static final exploreFeed = GlobalKey<NavigatorState>(
    debugLabel: 'explore-feed',
  );

  /// Notifications tab navigator key.
  static final notifications = GlobalKey<NavigatorState>(
    debugLabel: 'notifications',
  );

  /// Inbox tab navigator key (Messages + Notifications).
  static final inbox = GlobalKey<NavigatorState>(debugLabel: 'inbox');

  /// Profile tab navigator key for grid mode (no video index).
  static final profileGrid = GlobalKey<NavigatorState>(
    debugLabel: 'profile-grid',
  );

  /// Profile tab navigator key for feed mode (with video index).
  static final profileFeed = GlobalKey<NavigatorState>(
    debugLabel: 'profile-feed',
  );

  /// Liked videos navigator key for grid mode (no video index).
  static final likedVideosGrid = GlobalKey<NavigatorState>(
    debugLabel: 'liked-videos-grid',
  );

  /// Liked videos navigator key for feed mode (with video index).
  static final likedVideosFeed = GlobalKey<NavigatorState>(
    debugLabel: 'liked-videos-feed',
  );
}
