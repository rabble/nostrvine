// ABOUTME: Derived provider that parses router location into structured context
// ABOUTME: Single source of truth for "what page are we on?" with route types and parsing

import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/liked_videos_screen_router.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:riverpod/riverpod.dart';
import 'package:unified_logger/unified_logger.dart';

/// Route types supported by the app
enum RouteType {
  home,
  explore,
  notifications,
  inbox, // Inbox screen (Messages + Notifications combined)
  profile,
  likedVideos, // Current user's liked videos feed
  hashtag, // Still supported as push route within explore
  categoryGallery, // Category gallery pushed from explore categories
  search,
  videoRecorder, // Video recorder screen
  videoEditor, // Video editor screen
  videoMetadata, // Video editor meta screen
  importKey,
  settings,
  relaySettings, // Relay configuration screen
  relayDiagnostic, // Relay connectivity diagnostics
  blossomSettings, // Blossom media server settings
  notificationSettings, // Notification preferences
  keyManagement, // Key backup/export screen
  safetySettings, // Safety and privacy settings
  contentFilters, // Content filter preferences (Show/Warn/Hide)
  editProfile, // Profile editing screen
  clips, // Clip library screen
  drafts, // Draft library screen
  welcome, // Welcome/onboarding screen
  developerOptions, // Developer options (hidden, unlock by tapping version 7x)
  loginOptions, // Login options screen (choose login method)
  following, // Following list screen
  followers, // Followers list screen
  videoFeed, // Legacy route alias — resolved same as pooledVideoFeed
  profileView, // Other user's profile (fullscreen, no bottom nav)
  curatedList, // Curated video list screen (NIP-51 kind 30005)
  discoverLists, // Discover public lists screen
  creatorAnalytics, // Creator analytics dashboard (profile owner)
  sound, // Sound detail screen for audio reuse
  originalSound, // Original sound detail screen (creator's own audio)
  contentPreferences, // Content preferences (language, audio, filters)
  appLanguage, // App language picker (UI locale override)
  supportCenter, // Support center (bug reports, logs, FAQ, legal links)
  legal, // Legal screen (ToS, Privacy, Safety, DMCA, Licenses)
  nostrSettings, // Nostr settings (relays, media servers, keys, account)
  blueskySettings, // Bluesky crosspost publishing settings
  secureAccount,
  pooledVideoFeed, // Pooled fullscreen video feed (uses pooled_video_player)
  videoDetail, // Video detail screen (deep link to specific video)
  conversation, // DM conversation detail (pushed from inbox)
  messageRequests, // Message requests inbox (pushed from inbox)
  requestPreview, // Message request preview (pushed from requests)
}

/// Structured representation of a route
class RouteContext {
  const RouteContext({
    required this.type,
    this.videoIndex,
    this.appSlug,
    this.npub,
    this.hashtag,
    this.categoryName,
    this.searchTerm,
    this.listId,
    this.soundId,
    this.videoId,
    this.draftId,
    this.conversationId,
  });

  final RouteType type;
  final int? videoIndex;
  final String? appSlug;
  final String? npub;
  final String? hashtag;
  final String? categoryName;
  final String? searchTerm;
  final String? listId;
  final String? soundId;
  final String? videoId;
  final String? draftId;
  final String? conversationId;
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
      return RouteContext(type: RouteType.profile, npub: npub);

    case 'notifications':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(type: RouteType.notifications, videoIndex: index);

    case 'inbox':
      // /inbox - inbox screen
      // /inbox/conversation/:id - conversation detail
      // /inbox/message-requests - message requests inbox
      // /inbox/message-requests/:id - request preview
      if (segments.length > 2 && segments[1] == 'conversation') {
        final conversationId = Uri.decodeComponent(segments[2]);
        return RouteContext(
          type: RouteType.conversation,
          conversationId: conversationId,
        );
      }
      if (segments.length > 1 && segments[1] == 'message-requests') {
        if (segments.length > 2) {
          final conversationId = Uri.decodeComponent(segments[2]);
          return RouteContext(
            type: RouteType.requestPreview,
            conversationId: conversationId,
          );
        }
        return const RouteContext(type: RouteType.messageRequests);
      }
      return const RouteContext(type: RouteType.inbox);

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

    case 'categories':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final categoryName = Uri.decodeComponent(segments[1]);
      return RouteContext(
        type: RouteType.categoryGallery,
        categoryName: categoryName,
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

    case 'video-recorder':
      return const RouteContext(type: RouteType.videoRecorder);

    case 'video-editor':
      if (segments.length > 1) {
        final draftId = Uri.decodeComponent(segments[1]);
        return RouteContext(type: RouteType.videoEditor, draftId: draftId);
      }
      return const RouteContext(type: RouteType.videoEditor);

    case 'video-metadata':
      return const RouteContext(type: RouteType.videoMetadata);

    case 'settings':
      return const RouteContext(type: RouteType.settings);

    case 'apps':
      if (segments.length > 1) {
        return RouteContext(
          type: RouteType.settings,
          appSlug: Uri.decodeComponent(segments[1]),
        );
      }
      return const RouteContext(type: RouteType.settings, appSlug: '');

    case 'creator-analytics':
      return const RouteContext(type: RouteType.creatorAnalytics);

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

    case 'content-filters':
      return const RouteContext(type: RouteType.contentFilters);

    case 'content-preferences':
      return const RouteContext(type: RouteType.contentPreferences);

    case 'app-language':
      return const RouteContext(type: RouteType.appLanguage);

    case 'support-center':
      return const RouteContext(type: RouteType.supportCenter);

    case 'legal':
      return const RouteContext(type: RouteType.legal);

    case 'nostr-settings':
      return const RouteContext(type: RouteType.nostrSettings);

    case 'bluesky-settings':
      return const RouteContext(type: RouteType.blueskySettings);

    case 'edit-profile':
    case 'setup-profile':
      // Profile editing screens - standalone routes outside ShellRoute
      return const RouteContext(type: RouteType.editProfile);

    case 'clips':
      // Clip library screen - standalone route outside ShellRoute
      return const RouteContext(type: RouteType.clips);

    case 'drafts':
      // Draft library screen - standalone route outside ShellRoute
      return const RouteContext(type: RouteType.drafts);

    case 'import-key':
      return const RouteContext(type: RouteType.importKey);

    case 'welcome':
      // /welcome/login-options → loginOptions
      if (segments.length > 1 && segments[1] == 'login-options') {
        return const RouteContext(type: RouteType.loginOptions);
      }
      return const RouteContext(type: RouteType.welcome);

    case 'developer-options':
      return const RouteContext(type: RouteType.developerOptions);
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

    case 'original-sound':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final originalSoundPubkey = Uri.decodeComponent(segments[1]);
      return RouteContext(
        type: RouteType.originalSound,
        npub: originalSoundPubkey,
      );

    case 'profile-view':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final profileViewNpub = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.profileView, npub: profileViewNpub);

    case 'secure-account':
      return const RouteContext(type: RouteType.secureAccount);

    case 'pooled-video-feed':
      return const RouteContext(type: RouteType.pooledVideoFeed);

    case 'video':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final videoId = Uri.decodeComponent(segments[1]);
      return RouteContext(type: RouteType.videoDetail, videoId: videoId);

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
      return VideoFeedPage.pathForIndex(index);

    case RouteType.explore:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return ExploreScreen.pathForIndex(index);
      }
      return ExploreScreen.path;

    case RouteType.notifications:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return NotificationsPage.pathForIndex(index);
      }
      return NotificationsPage.path;

    case RouteType.conversation:
      return ConversationPage.pathForId(context.conversationId ?? '');

    case RouteType.inbox:
      return InboxPage.path;

    case RouteType.messageRequests:
      return MessageRequestsPage.path;

    case RouteType.requestPreview:
      final id = Uri.encodeComponent(context.conversationId ?? '');
      return '/inbox/message-requests/$id';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? '');
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return ProfileScreenRouter.pathForIndex(npub, index);
      }
      return ProfileScreenRouter.pathForNpub(npub);

    case RouteType.likedVideos:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return LikedVideosScreenRouter.pathForIndex(index);
      }
      return LikedVideosScreenRouter.path;

    case RouteType.hashtag:
      final hashtag = context.hashtag ?? '';
      return HashtagScreenRouter.pathForTag(hashtag);

    case RouteType.categoryGallery:
      final categoryName = context.categoryName;
      if (categoryName == null || categoryName.isEmpty) {
        return ExploreScreen.path;
      }
      return CategoryGalleryScreen.locationFor(categoryName);

    case RouteType.search:
      // Grid mode (null videoIndex):
      //   - With term: '/search/{term}'
      //   - Without term: '/search'
      // Feed mode (videoIndex set):
      //   - With term: '/search/{term}/{index}'
      //   - Without term (legacy): '/search/{index}'
      if (context.searchTerm != null) {
        final rawIndex = context.videoIndex;
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return SearchScreenPure.pathForTerm(
          term: context.searchTerm,
          index: index,
        );
      }

      // Legacy format without search term
      if (context.videoIndex == null) return SearchScreenPure.path;
      final rawIndex = context.videoIndex!;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '${SearchScreenPure.path}/$index';

    case RouteType.videoRecorder:
      return VideoRecorderScreen.path;

    case RouteType.videoEditor:
      if (context.draftId != null) {
        return '${VideoEditorScreen.path}/${Uri.encodeComponent(context.draftId!)}';
      }
      return VideoEditorScreen.path;

    case RouteType.videoMetadata:
      return VideoMetadataScreen.path;

    case RouteType.settings:
      if (context.appSlug != null) {
        if (context.appSlug!.isEmpty) {
          return AppsDirectoryScreen.path;
        }
        return AppDetailScreen.pathForSlug(
          Uri.encodeComponent(context.appSlug!),
        );
      }
      return SettingsScreen.path;

    case RouteType.relaySettings:
      return RelaySettingsScreen.path;

    case RouteType.relayDiagnostic:
      return RelayDiagnosticScreen.path;

    case RouteType.blossomSettings:
      return BlossomSettingsScreen.path;

    case RouteType.notificationSettings:
      return NotificationSettingsScreen.path;

    case RouteType.keyManagement:
      return KeyManagementScreen.path;

    case RouteType.safetySettings:
      return SafetySettingsScreen.path;

    case RouteType.contentFilters:
      return ContentFiltersScreen.path;

    case RouteType.contentPreferences:
      return ContentPreferencesScreen.path;

    case RouteType.appLanguage:
      return AppLanguageScreen.path;

    case RouteType.supportCenter:
      return SupportCenterScreen.path;

    case RouteType.legal:
      return LegalScreen.path;

    case RouteType.nostrSettings:
      return NostrSettingsScreen.path;

    case RouteType.blueskySettings:
      return BlueskySettingsScreen.path;

    case RouteType.editProfile:
      return ProfileSetupScreen.editPath;

    case RouteType.importKey:
      return KeyImportScreen.path;

    case RouteType.clips:
      return LibraryScreen.clipsPath;

    case RouteType.drafts:
      return LibraryScreen.draftsPath;

    case RouteType.welcome:
      return WelcomeScreen.path;

    case RouteType.developerOptions:
      return DeveloperOptionsScreen.path;

    case RouteType.loginOptions:
      return WelcomeScreen.loginOptionsPath;

    case RouteType.following:
      return FollowingScreenRouter.pathForPubkey(context.npub ?? '');

    case RouteType.followers:
      return FollowersScreenRouter.pathForPubkey(context.npub ?? '');

    case RouteType.videoFeed:
      return PooledFullscreenVideoFeedScreen.path;

    case RouteType.profileView:
      final npub = Uri.encodeComponent(context.npub ?? '');
      return OtherProfileScreen.pathForNpub(npub);

    case RouteType.curatedList:
      return CuratedListFeedScreen.pathForId(context.listId ?? '');

    case RouteType.discoverLists:
      return DiscoverListsScreen.path;

    case RouteType.creatorAnalytics:
      return CreatorAnalyticsScreen.path;

    case RouteType.sound:
      return SoundDetailScreen.pathForId(context.soundId ?? '');

    case RouteType.originalSound:
      return OriginalSoundDetailScreen.pathForPubkey(context.npub ?? '');

    case RouteType.secureAccount:
      return SecureAccountScreen.path;

    case RouteType.pooledVideoFeed:
      return PooledFullscreenVideoFeedScreen.path;

    case RouteType.videoDetail:
      return VideoDetailScreen.pathForId(context.videoId ?? '');
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
    final ctx = parseRoute(loc);
    Log.info(
      'CTX derive: type=${ctx.type} npub=${ctx.npub} index=${ctx.videoIndex}',
      name: 'Route',
      category: LogCategory.system,
    );
    yield ctx;
  }
});
