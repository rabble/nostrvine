// ABOUTME: Screen for /list/:pubkey/:listId universal links (web-canonical shape)
// ABOUTME: Resolves a NIP-51 kind 30005 list by author + d-tag, then shows the list feed

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';

/// Resolves a `/list/:pubkey/:listId` link into [CuratedListFeedScreen].
///
/// This is the web-canonical public URL shape for NIP-51 kind 30005 lists,
/// which are addressed by author + d-tag. Unlike the internal
/// `/list/:listId` route — which relies on route extras and locally stored
/// lists — this screen fetches the list from relays, so deep links to lists
/// the user has never seen still open.
class CuratedListByAuthorScreen extends ConsumerWidget {
  const CuratedListByAuthorScreen({
    required this.authorPubkey,
    required this.listId,
    super.key,
  });

  /// Route name for this screen.
  static const routeName = 'listByAuthor';

  /// Path for this route. Derived from [CuratedListFeedScreen.basePath] so
  /// the GoRoute pattern and [pathFor] can never diverge.
  static const path = '${CuratedListFeedScreen.basePath}/:pubkey/:listId';

  /// Build path for a list addressed by author + d-tag.
  static String pathFor({required String pubkey, required String listId}) {
    return '${CuratedListFeedScreen.basePath}/${Uri.encodeComponent(pubkey)}'
        '/${Uri.encodeComponent(listId)}';
  }

  /// Author pubkey (lowercase hex).
  final String authorPubkey;

  /// List d-tag identifier.
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(
      publicCuratedListProvider(authorPubkey: authorPubkey, listId: listId),
    );

    return listAsync.when(
      data: (list) {
        if (list == null) {
          return const _ListUnavailableView();
        }
        return CuratedListFeedScreen(
          listId: list.id,
          listName: list.name,
          videoIds: list.videoEventIds,
          authorPubkey: list.pubkey ?? authorPubkey,
        );
      },
      loading: () => const _ListLoadingView(),
      error: (error, stackTrace) => const _ListUnavailableView(),
    );
  }
}

class _ListLoadingView extends StatelessWidget {
  const _ListLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: context.l10n.routeDefaultListName,
        showBackButton: true,
        // safePop: on a cold-start deep link this is the only route, and a
        // raw pop would throw GoError.
        onBackPressed: context.safePop,
      ),
      body: const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}

class _ListUnavailableView extends StatelessWidget {
  const _ListUnavailableView();

  @override
  Widget build(BuildContext context) {
    return RouteErrorScreen(
      message: context.l10n.curatedListFailedToLoad,
      title: context.l10n.routeDefaultListName,
      showBackButton: true,
      onBackPressed: context.safePop,
    );
  }
}
