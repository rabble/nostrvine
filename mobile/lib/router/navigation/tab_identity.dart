// ABOUTME: Single source of truth for the bottom-nav tab <-> RouteType mapping
// ABOUTME: Replaces eight divergent private copies across five files (#3337)

import 'package:openvine/router/providers/page_context_provider.dart';

/// Bottom-nav tab index that owns [type], or `null` when [type] is not
/// reachable from the bottom nav.
///
/// Tab 2 is the inbox branch, which hosts **both** `/inbox` and
/// `/notifications/:index` (see the `NavigatorKeys.inbox` branch in
/// `router/routes/shell.dart`). Omitting [RouteType.inbox] here is what made
/// Android system back close the app from the Inbox tab: the route was never
/// recorded in tab history and no tab owned it, so the handler reported the
/// press unhandled and the OS finished the activity (#3337).
int? tabIndexFromRouteType(RouteType type) => switch (type) {
  RouteType.home => 0,
  // A hashtag grid is pushed from Explore and belongs to its tab.
  RouteType.explore || RouteType.hashtag => 1,
  RouteType.notifications || RouteType.inbox => 2,
  RouteType.profile => 3,
  _ => null,
};

/// Route type used to key per-tab state (last scroll position) for [index].
///
/// Tab 2 resolves to [RouteType.notifications] because that is the only
/// route in the inbox branch carrying a position to restore.
RouteType routeTypeForTab(int index) => switch (index) {
  0 => RouteType.home,
  1 => RouteType.explore,
  2 => RouteType.notifications,
  3 => RouteType.profile,
  _ => RouteType.home,
};

/// Human-readable tab name, for logs only.
String tabName(int index) => switch (index) {
  0 => 'Home',
  1 => 'Explore',
  2 => 'Inbox',
  3 => 'Profile',
  _ => 'Unknown',
};
