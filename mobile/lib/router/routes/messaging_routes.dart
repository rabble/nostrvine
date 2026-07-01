// ABOUTME: DM / message-request routes (conversation, requests, request preview)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';

List<RouteBase> messagingRoutes() {
  return [
    // DM conversation detail (pushed from inbox, no bottom nav)
    GoRoute(
      path: ConversationPage.pathPattern,
      name: ConversationPage.routeName,
      builder: (ctx, st) {
        final id = st.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return RouteErrorScreen(
            message: ctx.l10n.routeInvalidConversationId,
          );
        }
        final participantPubkeys = stringListRouteExtra(st.extra);
        return ConversationPage(
          conversationId: id,
          participantPubkeys: participantPubkeys,
        );
      },
    ),

    // Message requests inbox (pushed from inbox, no bottom nav)
    GoRoute(
      path: MessageRequestsPage.path,
      name: MessageRequestsPage.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const MessageRequestsPage(),
    ),

    // Message request preview (pushed from requests inbox)
    GoRoute(
      path: RequestPreviewPage.pathPattern,
      name: RequestPreviewPage.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) {
        final id = st.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidRequestId);
        }
        // Pubkeys are optional — the page loads them from the DB
        // when not provided (e.g. deep link).
        final participantPubkeys = stringListRouteExtra(st.extra);
        return RequestPreviewPage(
          conversationId: id,
          participantPubkeys: participantPubkeys,
        );
      },
    ),
  ];
}

@visibleForTesting
List<String> stringListRouteExtra(Object? extra) {
  if (extra is! Iterable) return const [];

  final values = <String>[];
  for (final item in extra) {
    if (item is! String) return const [];
    values.add(item);
  }
  return List<String>.unmodifiable(values);
}
