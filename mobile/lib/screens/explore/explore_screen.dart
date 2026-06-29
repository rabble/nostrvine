// ABOUTME: Explore screen Page — thin route entry that provides
// ABOUTME: ExploreTabsCubit to the ExploreView body.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/screens/explore/explore_view.dart';

/// Explore screen: a thin tabs Page over [ExploreTabsCubit] + [ExploreView].
class ExploreScreen extends ConsumerWidget {
  /// Creates the explore screen, optionally selecting [initialTabName].
  const ExploreScreen({super.key, this.initialTabName});

  static const _routeTabNames = <String>{
    'classics',
    'new',
    'popular',
    'categories',
    exploreForYouTabName,
    'lists',
    'apps',
  };

  /// Route name for this screen.
  static const routeName = 'explore';

  /// Path for this route (grid mode).
  static const path = '/explore';

  /// Path for this route with index (feed mode).
  static const pathWithIndex = '/explore/:index';

  /// Path for selecting a specific tab by name (grid mode).
  /// Valid URL slugs: 'classics', 'new', 'popular', 'categories',
  /// 'for-you', 'lists', 'apps'.
  static const pathTabSubpath = '/explore/tab/:name';

  /// Build path for grid mode or specific index.
  static String pathForIndex(int? index) =>
      index == null ? path : '$path/$index';

  /// Build path for selecting a specific tab by name.
  static String pathForTab(String name) =>
      '/explore/tab/${tabSlugForName(name)}';

  /// Convert an internal tab name to the public URL slug.
  static String tabSlugForName(String name) => switch (name) {
    exploreForYouTabName => exploreForYouTabSlug,
    _ => name,
  };

  /// Convert a URL path parameter to the internal tab name.
  static String? tabNameFromPathParameter(String? slug) {
    if (slug == null) return null;
    if (slug.contains('_')) return null;
    final name = switch (slug) {
      exploreForYouTabSlug => exploreForYouTabName,
      _ => slug,
    };
    return _routeTabNames.contains(name) ? name : null;
  }

  /// Optional tab name to select on first build. Takes precedence over
  /// [forceExploreTabNameProvider] and the saved [exploreTabIndexProvider].
  final String? initialTabName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      // topHashtagsServiceProvider is a stable keepAlive Provider that is never
      // invalidated, so ref.read is safe here (see state_management.md §1).
      create: (_) =>
          ExploreTabsCubit(topHashtags: ref.read(topHashtagsServiceProvider)),
      child: ExploreView(initialTabName: initialTabName),
    );
  }
}
