// ABOUTME: Shared go_router page-name resolution for analytics route settings.
// ABOUTME: Keeps ShellRoute pages from falling back to unknown_route.

import 'package:go_router/go_router.dart';

/// Returns the stable page name go_router would put on a regular [GoRoute].
///
/// Shell route states do not receive [GoRouterState.name] or
/// [GoRouterState.path], so fall back to the matched leaf route exposed through
/// [GoRouterState.topRoute].
String? goRouterPageName(GoRouterState state) {
  return state.name ?? state.path ?? state.topRoute?.name ?? state.fullPath;
}
