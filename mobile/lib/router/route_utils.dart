// ABOUTME: Route parsing and building utilities
// ABOUTME: Converts between URLs and structured route context

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

/// Extra data for curated list route (passed via GoRouter extra)
class CuratedListRouteExtra {
  const CuratedListRouteExtra({
    required this.listName,
    this.videoIds,
    this.authorPubkey,
  });

  final String listName;
  final List<String>? videoIds;
  final String? authorPubkey;
}

/// Extra data for video editor route (passed via GoRouter extra)
class VideoEditorRouteExtra {
  const VideoEditorRouteExtra({
    required this.videoPath,
    this.externalAudioEventId,
    this.externalAudioUrl,
    this.externalAudioIsBundled = false,
    this.externalAudioAssetPath,
  });

  final String videoPath;
  final String? externalAudioEventId;
  final String? externalAudioUrl;
  final bool externalAudioIsBundled;
  final String? externalAudioAssetPath;
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

    default:
      return const RouteContext(type: RouteType.home, videoIndex: 0);
  }
}

/// Build a URL path from a RouteContext
/// Encodes dynamic parameters and normalizes indices to >= 0
String buildRoute(RouteContext context) {
  switch (context.type) {
    case RouteType.home:
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '/home/$index';

    case RouteType.explore:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/explore/$index';
      }
      return '/explore';

    case RouteType.notifications:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/notifications/$index';
      }
      return '/notifications';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? '');
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/profile/$npub/$index';
      }
      return '/profile/$npub';

    case RouteType.likedVideos:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/liked-videos/$index';
      }
      return '/liked-videos';

    case RouteType.hashtag:
      final hashtag = Uri.encodeComponent(context.hashtag ?? '');
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/hashtag/$hashtag/$index';
      }
      return '/hashtag/$hashtag';

    case RouteType.search:
      // Grid mode (null videoIndex):
      //   - With term: '/search/{term}'
      //   - Without term: '/search'
      // Feed mode (videoIndex set):
      //   - With term: '/search/{term}/{index}'
      //   - Without term (legacy): '/search/{index}'
      if (context.searchTerm != null) {
        final encodedTerm = Uri.encodeComponent(context.searchTerm!);
        if (context.videoIndex == null) {
          return '/search/$encodedTerm';
        }
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/search/$encodedTerm/$index';
      }

      // Legacy format without search term
      if (context.videoIndex == null) return '/search';
      final rawIndex = context.videoIndex!;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '/search/$index';

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

    case RouteType.importKey:
      return '/import-key';

    case RouteType.clips:
      return '/clips';

    case RouteType.welcome:
      return '/welcome';

    case RouteType.developerOptions:
      return '/developer-options';

    case RouteType.loginOptions:
      return '/login-options';

    case RouteType.authNative:
      return '/auth-native';
    case RouteType.following:
      return '/following/${context.npub ?? ''}';

    case RouteType.followers:
      return '/followers/${context.npub ?? ''}';

    case RouteType.videoFeed:
      return '/video-feed';

    case RouteType.profileView:
      final npub = Uri.encodeComponent(context.npub ?? '');
      return '/profile-view/$npub';
    case RouteType.curatedList:
      final listId = Uri.encodeComponent(context.listId ?? '');
      return '/list/$listId';

    case RouteType.discoverLists:
      return '/discover-lists';

    case RouteType.sound:
      return '/sound/${context.soundId ?? ''}';
    case RouteType.secureAccount:
      return '/secure-account';
  }
}
