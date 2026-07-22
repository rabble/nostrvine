// ABOUTME: Library routes (drafts / clips / clips-only / sounds tabs)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/screens/library_screen.dart';

List<RouteBase> libraryRoutes() {
  return [
    GoRoute(
      path: LibraryScreen.draftsPath,
      name: LibraryScreen.draftsRouteName,
      pageBuilder: (_, state) =>
          fadeUpwardsPage(state: state, child: const LibraryScreen()),
    ),
    GoRoute(
      path: LibraryScreen.clipsPath,
      name: LibraryScreen.clipsRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(initialTabIndex: 1),
      ),
    ),
    GoRoute(
      path: LibraryScreen.clipsOnlyPath,
      name: LibraryScreen.clipsOnlyRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        // `type` scopes the clips to the recorder's mode (stop-motion vs normal);
        // absent → both types (the standalone default).
        child: LibraryScreen(
          tabsMode: LibraryTabsMode.clipsOnly,
          clipTypeFilter: LibraryClipTypeFilter.fromQuery(
            state.uri.queryParameters['type'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: LibraryScreen.soundsPath,
      name: LibraryScreen.soundsRouteName,
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: const LibraryScreen(initialTabIndex: 2),
      ),
    ),
  ];
}
