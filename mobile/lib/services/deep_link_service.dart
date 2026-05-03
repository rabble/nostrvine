// ABOUTME: Service for handling universal/deep links from divine.video URLs
// ABOUTME: Parses video and profile URLs and routes to appropriate screens

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:unified_logger/unified_logger.dart';

/// Types of deep links supported by the app
enum DeepLinkType {
  video,
  profile,
  hashtag,
  search,
  invite,
  signerCallback,
  unknown,
}

/// Represents a parsed deep link
class DeepLink {
  const DeepLink({
    required this.type,
    this.videoRef,
    this.npub,
    this.hashtag,
    this.searchTerm,
    this.inviteCode,
    this.index,
  });

  final DeepLinkType type;

  /// Raw `/video/:id` route reference from the incoming URL.
  ///
  /// This may be a hex event ID, a first-party stable ID / d-tag, or a
  /// NIP-19 reference such as `note1`, `nevent1`, or `naddr1`.
  final String? videoRef;
  final String? npub;
  final String? hashtag;
  final String? searchTerm;
  final String? inviteCode;
  final int? index; // Optional video index for feed view

  @override
  String toString() {
    final indexStr = index != null ? ', index: $index' : '';
    switch (type) {
      case DeepLinkType.video:
        return 'DeepLink(type: video, videoRef: $videoRef)';
      case DeepLinkType.profile:
        return 'DeepLink(type: profile, npub: $npub$indexStr)';
      case DeepLinkType.hashtag:
        return 'DeepLink(type: hashtag, hashtag: $hashtag$indexStr)';
      case DeepLinkType.search:
        return 'DeepLink(type: search, searchTerm: $searchTerm$indexStr)';
      case DeepLinkType.invite:
        return 'DeepLink(type: invite, inviteCode: $inviteCode)';
      case DeepLinkType.signerCallback:
        return 'DeepLink(type: signerCallback)';
      case DeepLinkType.unknown:
        return 'DeepLink(type: unknown)';
    }
  }
}

/// Service for handling universal/deep links
class DeepLinkService {
  DeepLinkService();

  final _appLinks = AppLinks();
  StreamSubscription? _subscription;
  final _controller = StreamController<DeepLink>.broadcast();

  /// Stream of parsed deep links
  Stream<DeepLink> get linkStream => _controller.stream;

  /// Initialize deep link handling
  Future<void> initialize() async {
    try {
      // Check if app was opened via deep link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        Log.info(
          '📱 App opened with deep link: $initialUri',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        final deepLink = DeepLinkService.parseDeepLink(initialUri.toString());
        _controller.add(deepLink);
      }

      // Listen for deep links while app is running
      _subscription = _appLinks.uriLinkStream.listen((uri) {
        Log.info(
          '📱 Received deep link while running: $uri',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        final deepLink = DeepLinkService.parseDeepLink(uri.toString());
        _controller.add(deepLink);
      });
    } catch (e) {
      Log.error(
        'Error initializing deep link service: $e',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
    }
  }

  /// Parse a divine.video URL into a [DeepLink].
  ///
  /// Pure: no instance state is touched, safe to call from route redirects.
  static DeepLink parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Handle divine:// callback from NIP-46 signer apps.
      // The signer opens this scheme to bring our app back to foreground
      // after the user approves the connection. We emit signerCallback so
      // listeners can trigger relay reconnection for the nostrconnect session.
      if (uri.scheme == 'divine') {
        Log.info(
          'Received NIP-46 signer callback: $url',
          name: 'DeepLinkService',
          category: LogCategory.auth,
        );
        return const DeepLink(type: DeepLinkType.signerCallback);
      }

      // Accept divine.video itself plus any subdomain
      // (login.divine.video, staging.divine.video, etc.). Sibling and
      // lookalike hosts like notdivine.video or divine.video.evil.com
      // must still be rejected.
      final host = uri.host.toLowerCase();
      final isDivineHost =
          host == 'divine.video' || host.endsWith('.divine.video');
      if (!isDivineHost) {
        Log.warning(
          'Ignoring deep link from non-divine.video domain: ${uri.host}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return const DeepLink(type: DeepLinkType.unknown);
      }

      final pathSegments = uri.pathSegments;

      // Handle /video/{videoRef}. The path segment is preserved verbatim;
      // downstream resolution accepts raw IDs, stable IDs, and NIP-19 refs.
      if (pathSegments.length == 2 && pathSegments[0] == 'video') {
        final videoRef = pathSegments[1];
        Log.info(
          '📱 Parsed video deep link ref: $videoRef',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(type: DeepLinkType.video, videoRef: videoRef);
      }

      // Handle /profile/{npub} or /profile/{npub}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'profile') {
        final npub = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed profile deep link: $npub${index != null ? " (index: $index)" : ""}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(type: DeepLinkType.profile, npub: npub, index: index);
      }

      // Handle /hashtag/{tag} or /hashtag/{tag}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'hashtag') {
        final hashtag = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed hashtag deep link: $hashtag${index != null ? " (index: $index)" : ""}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(
          type: DeepLinkType.hashtag,
          hashtag: hashtag,
          index: index,
        );
      }

      // Handle /search/{term} or /search/{term}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'search') {
        final searchTerm = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed search deep link: $searchTerm${index != null ? " (index: $index)" : ""}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(
          type: DeepLinkType.search,
          searchTerm: searchTerm,
          index: index,
        );
      }

      // Handle /invite/{code} or /invite?code=ABCD-EFGH
      if (pathSegments.isNotEmpty && pathSegments[0] == 'invite') {
        final inviteCode = pathSegments.length > 1
            ? Uri.decodeComponent(pathSegments[1])
            : uri.queryParameters['code'];

        if (inviteCode != null && inviteCode.isNotEmpty) {
          Log.info(
            'Parsed invite deep link: $inviteCode',
            name: 'DeepLinkService',
            category: LogCategory.ui,
          );
          return DeepLink(type: DeepLinkType.invite, inviteCode: inviteCode);
        }

        return const DeepLink(type: DeepLinkType.unknown);
      }

      Log.warning(
        'Unknown deep link path: ${uri.path}',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
      return const DeepLink(type: DeepLinkType.unknown);
    } catch (e) {
      Log.error(
        'Error parsing deep link: $e',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
      return const DeepLink(type: DeepLinkType.unknown);
    }
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
