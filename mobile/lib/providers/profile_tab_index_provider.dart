// ABOUTME: StateProvider persisting the currently selected profile tab index
// ABOUTME: Survives ProfileGridView unmount/remount during navigation transitions.

import 'package:flutter_riverpod/legacy.dart';

/// Cache key for the selected profile tab index.
///
/// [viewerPubkeyHex] scopes the cache to the signed-in identity so switching
/// accounts cannot restore another viewer's tab selection for the same target
/// profile.
typedef ProfileTabIndexKey = ({
  String? viewerPubkeyHex,
  String targetPubkeyHex,
});

/// Remembers the currently selected tab index per viewer/profile pair.
///
/// `ProfileGridView`'s [TabController] is recreated whenever the profile
/// subtree is unmounted and remounted. This happens on any navigation that
/// briefly takes the URL off the profile route (e.g. pushing the fullscreen
/// pooled video feed) because `_ProfileContentView` guards its build on
/// `routeContext.type == RouteType.profile` and returns an empty widget
/// otherwise — which throws away `TabController` state.
///
/// Stored as a Map so multiple profiles (own + recently visited others) each
/// keep their own position without bleeding into each other or across account
/// switches.
final profileTabIndexProvider = StateProvider<Map<ProfileTabIndexKey, int>>(
  (ref) => <ProfileTabIndexKey, int>{},
);
