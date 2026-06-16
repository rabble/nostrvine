import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared navigation and URL handling for linkified text renderers.
final class LinkifiedTextNavigation {
  const LinkifiedTextNavigation._();

  static void navigateToHashtagFeed(
    BuildContext context,
    String hashtag, {
    VoidCallback? beforeNavigate,
  }) {
    beforeNavigate?.call();
    context.push(HashtagScreenRouter.pathForTag(hashtag));
  }

  static void navigateToProfile(
    BuildContext context,
    String hexPubkey, {
    VoidCallback? beforeNavigate,
  }) {
    beforeNavigate?.call();
    context.pushOtherProfile(hexPubkey);
  }

  static void navigateToVideo(
    BuildContext context,
    String routeReference, {
    VoidCallback? beforeNavigate,
  }) {
    beforeNavigate?.call();
    context.push(VideoDetailScreen.pathForId(routeReference));
  }

  static void navigateToSearch(
    BuildContext context,
    String username, {
    VoidCallback? beforeNavigate,
  }) {
    beforeNavigate?.call();
    context.push(
      SearchResultsPage.pathForQuery(username, requestFocusOnMount: false),
    );
  }

  static Future<void> handleUrlTap(
    String rawUrl, {
    VoidCallback? beforeNavigate,
    Future<void> Function(String rawUrl)? customHandler,
  }) async {
    beforeNavigate?.call();
    if (customHandler != null) {
      await customHandler(rawUrl);
      return;
    }
    await launchRawUrl(rawUrl);
  }

  static Future<void> launchRawUrl(String rawUrl) async {
    final uri = uriForRawUrl(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Uri? uriForRawUrl(String rawUrl) {
    if (_emailRegex.hasMatch(rawUrl)) {
      return Uri(scheme: 'mailto', path: rawUrl);
    }
    final normalizedUrl =
        rawUrl.startsWith(
          RegExp('https?://', caseSensitive: false),
        )
        ? rawUrl
        : 'https://$rawUrl';
    return Uri.tryParse(normalizedUrl);
  }
}

final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);
