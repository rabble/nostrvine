// ABOUTME: Derived provider that parses router location into structured context
// ABOUTME: Single source of truth for "what page are we on?" with route types and parsing

import 'package:riverpod/riverpod.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Route types supported by the app
enum RouteType {
  home,
  explore,
  notifications,
  profile,
  likedVideos, // Current user's liked videos feed
  hashtag, // Still supported as push route within explore
  search,
  camera,
  clipManager, // Clip management screen for recorded segments
  editVideo, // Video editor screen for text/sound overlays
  importKey,
  settings,
  relaySettings, // Relay configuration screen
  relayDiagnostic, // Relay connectivity diagnostics
  blossomSettings, // Blossom media server settings
  notificationSettings, // Notification preferences
  keyManagement, // Key backup/export screen
  safetySettings, // Safety and privacy settings
  editProfile, // Profile editing screen
  clips, // Clip library screen (formerly drafts)
  welcome, // Welcome/onboarding screen
  developerOptions, // Developer options (hidden, unlock by tapping version 7x)
  loginOptions, // Login options screen (choose login method)
  authNative, // Native email/password auth screen
  following, // Following list screen
  followers, // Followers list screen
  videoFeed, // Fullscreen video feed (pushed from grids)
  profileView, // Other user's profile (fullscreen, no bottom nav)
  curatedList, // Curated video list screen (NIP-51 kind 30005)
  discoverLists, // Discover public lists screen
  sound, // Sound detail screen for audio reuse
  secureAccount,
  newVideoFeed,
}

/// Structured representation of a route
class RouteContext {
  const RouteContext({
    required this.type,
    this.videoIndex,
    this.npub,
    this.hashtag,
    this.searchTerm,
    this.listId,
    this.soundId,
  });

  final RouteType type;
  final int? videoIndex;
  final String? npub;
  final String? hashtag;
  final String? searchTerm;
  final String? listId;
  final String? soundId;
}

/// Parse a URL path into a structured RouteContext
/// Normalizes negative indices to 0 and decodes URL-encoded parameters
RouteContext parseRoute(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) {
    return const RouteContext(type: RouteType.home, videoIndex: 0);
  }

  final firstSegment = segments[0];

  switch (firstSegment) {
    case 'home':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(type: RouteType.home, videoIndex: index);

    case 'explore':
      if (segments.length > 1) {
        final rawIndex = int.tryParse(segments[1]);
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.explore, videoIndex: index);
      }
      return const RouteContext(type: RouteType.explore);

    case 'profile':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final npub = Uri.decodeComponent(segments[1]); // Decode URL encoding
      // Grid mode (no index) vs feed mode (with index)
      if (segments.length > 2) {
        final rawIndex = int.tryParse(segments[2]) ?? 0;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: index,
        );
      }
      // Grid mode - no videoIndex
      return RouteContext(
        type: RouteType.profile,
        npub: npub,
        videoIndex: null,
      );

    case 'notifications':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(type: RouteType.notifications, videoIndex: index);

    case 'liked-videos':
      // /liked-videos - grid mode
      // /liked-videos/5 - feed mode at index 5
      if (segments.length > 1) {
        final rawIndex = int.tryParse(segments[1]);
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.likedVideos, videoIndex: index);
      }
      return const RouteContext(type: RouteType.likedVideos);

    case 'hashtag':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final tag = Uri.decodeComponent(segments[1]); // Decode URL encoding
      final rawIndex = segments.length > 2 ? int.tryParse(segments[2]) : null;
      final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(
        type: RouteType.hashtag,
        hashtag: tag,
        videoIndex: index,
      );

    case 'search':
      // /search - grid mode, no term
      // /search/term - grid mode with search term
      // /search/term/5 - feed mode with search term at index 5
      String? searchTerm;
      int? index;

      if (segments.length > 1) {
        // Try parsing segment 1 as index first
        final maybeIndex = int.tryParse(segments[1]);
        if (maybeIndex != null) {
          // Legacy format: /search/5 (no search term, just index)
          index = maybeIndex < 0 ? 0 : maybeIndex;
        } else {
          // segment 1 is search term
          searchTerm = Uri.decodeComponent(segments[1]);
          // Check for index in segment 2
          if (segments.length > 2) {
            final rawIndex = int.tryParse(segments[2]);
            index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
          }
        }
      }

      return RouteContext(
        type: RouteType.search,
        searchTerm: searchTerm,
        videoIndex: index,
      );

    case 'camera':
      return const RouteContext(type: RouteType.camera);

    case 'clip-manager':
      return const RouteContext(type: RouteType.clipManager);

    case 'edit-video':
      return const RouteContext(type: RouteType.editVideo);

    case 'settings':
      return const RouteContext(type: RouteType.settings);

    case 'relay-settings':
      return const RouteContext(type: RouteType.relaySettings);

    case 'relay-diagnostic':
      return const RouteContext(type: RouteType.relayDiagnostic);

    case 'blossom-settings':
      return const RouteContext(type: RouteType.blossomSettings);

    case 'notification-settings':
      return const RouteContext(type: RouteType.notificationSettings);

    case 'key-management':
      return const RouteContext(type: RouteType.keyManagement);

    case 'safety-settings':
      return const RouteContext(type: RouteType.safetySettings);

    case 'edit-profile':
    case 'setup-profile':
      // Profile editing screens - standalone routes outside ShellRoute
      return const RouteContext(type: RouteType.editProfile);

    case 'clips':
    case 'drafts': // Legacy route, redirects to clips
      // Clip library screen - standalone route outside ShellRoute
      return const RouteContext(type: RouteType.clips);

    case 'import-key':
      return const RouteContext(type: RouteType.importKey);

    case 'welcome':
      return const RouteContext(type: RouteType.welcome);

    case 'developer-options':
      return const RouteContext(type: RouteType.developerOptions);

    case 'login-options':
      return const RouteContext(type: RouteType.loginOptions);

    case 'auth-native':
      return const RouteContext(type: RouteType.authNative);
    case 'following':
      final followingPubkey = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.following, npub: followingPubkey);

    case 'followers':
      final followersPubkey = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.followers, npub: followersPubkey);

    case 'video-feed':
      return const RouteContext(type: RouteType.videoFeed);
    case 'list':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.explore);
      }
      final listId = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.curatedList, listId: listId);

    case 'discover-lists':
      return const RouteContext(type: RouteType.discoverLists);

    case 'sound':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final soundId = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.sound, soundId: soundId);

    case 'profile-view':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final profileViewNpub = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.profileView, npub: profileViewNpub);

    case 'secure-account':
      return const RouteContext(type: RouteType.secureAccount);

    case 'new-video-feed':
      return const RouteContext(type: RouteType.newVideoFeed);

    default:
      return const RouteContext(type: RouteType.home, videoIndex: 0);
  }
}

/// Build a canonical path string from a RouteContext
/// Used for route normalization to ensure consistent URL formats
String buildCanonicalPath(RouteContext context) {
  int normalizeIndex(int? raw) => (raw ?? 0) < 0 ? 0 : (raw ?? 0);

  switch (context.type) {
    case RouteType.home:
      return '/home/${normalizeIndex(context.videoIndex)}';

    case RouteType.explore:
      if (context.videoIndex != null) {
        return '/explore/${normalizeIndex(context.videoIndex)}';
      }
      return '/explore';

    case RouteType.notifications:
      return '/notifications/${normalizeIndex(context.videoIndex)}';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? '');
      if (context.videoIndex != null) {
        return '/profile/$npub/${normalizeIndex(context.videoIndex)}';
      }
      return '/profile/$npub';

    case RouteType.likedVideos:
      if (context.videoIndex != null) {
        return '/liked-videos/${normalizeIndex(context.videoIndex)}';
      }
      return '/liked-videos';

    case RouteType.hashtag:
      final tag = Uri.encodeComponent(context.hashtag ?? '');
      if (context.videoIndex != null) {
        return '/hashtag/$tag/${normalizeIndex(context.videoIndex)}';
      }
      return '/hashtag/$tag';

    case RouteType.search:
      if (context.searchTerm != null) {
        final term = Uri.encodeComponent(context.searchTerm!);
        if (context.videoIndex != null) {
          return '/search/$term/${normalizeIndex(context.videoIndex)}';
        }
        return '/search/$term';
      }
      if (context.videoIndex != null) {
        return '/search/${normalizeIndex(context.videoIndex)}';
      }
      return '/search';

    case RouteType.camera:
      return '/camera';

    case RouteType.clipManager:
      return '/clip-manager';

    case RouteType.editVideo:
      return '/edit-video';

    case RouteType.settings:
      return '/settings';

    case RouteType.relaySettings:
      return '/relay-settings';

    case RouteType.relayDiagnostic:
      return '/relay-diagnostic';

    case RouteType.blossomSettings:
      return '/blossom-settings';

    case RouteType.notificationSettings:
      return '/notification-settings';

    case RouteType.keyManagement:
      return '/key-management';

    case RouteType.safetySettings:
      return '/safety-settings';

    case RouteType.editProfile:
      return '/edit-profile';

    case RouteType.clips:
      return '/clips';

    case RouteType.importKey:
      return '/import-key';

    case RouteType.welcome:
      return '/welcome';

    case RouteType.developerOptions:
      return '/developer-options';

    case RouteType.loginOptions:
      return '/login-options';

    case RouteType.authNative:
      return '/auth-native';

    case RouteType.following:
      return '/following/${Uri.encodeComponent(context.npub ?? '')}';

    case RouteType.followers:
      return '/followers/${Uri.encodeComponent(context.npub ?? '')}';

    case RouteType.videoFeed:
      return '/video-feed';

    case RouteType.profileView:
      return '/profile-view/${Uri.encodeComponent(context.npub ?? '')}';

    case RouteType.curatedList:
      return '/list/${Uri.encodeComponent(context.listId ?? '')}';

    case RouteType.discoverLists:
      return '/discover-lists';

    case RouteType.sound:
      return '/sound/${Uri.encodeComponent(context.soundId ?? '')}';

    case RouteType.secureAccount:
      return '/secure-account';

    case RouteType.newVideoFeed:
      return '/new-video-feed';
  }
}

/// StreamProvider that derives structured page context from router location
///
/// Uses async* to emit immediately when the raw location stream has a value.
/// This ensures tests using Stream.value() get synchronous first emission.
///
/// Example:
/// ```dart
/// final context = ref.watch(pageContextProvider);
/// context.when(
///   data: (ctx) {
///     if (ctx.type == RouteType.home) {
///       // Show home feed videos
///     }
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => ErrorWidget(e),
/// );
/// ```
final pageContextProvider = StreamProvider<RouteContext>((ref) async* {
  // Get the raw location stream (overridable in tests)
  final locations = ref.watch(routerLocationStreamProvider);

  // Emit a context immediately if the stream is a single-value Stream.value(...)
  // (In tests we often use Stream.value('/profile/npub...'))
  await for (final loc in locations) {
    print('🟪 PAGE_CONTEXT DEBUG: Raw location = $loc');
    final ctx = parseRoute(loc);
    print(
      '🟪 PAGE_CONTEXT DEBUG: Parsed context = type=${ctx.type}, npub=${ctx.npub}, index=${ctx.videoIndex}',
    );
    Log.info(
      'CTX derive: type=${ctx.type} npub=${ctx.npub} index=${ctx.videoIndex}',
      name: 'Route',
      category: LogCategory.system,
    );
    yield ctx;
  }
});
