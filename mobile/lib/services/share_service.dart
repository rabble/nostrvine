// ABOUTME: Share service for generating Nostr event links and handling share actions
// ABOUTME: Supports nevent links, external app sharing, and clipboard operations

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for handling video sharing functionality
class ShareService {
  static const String _appUrl = 'https://divine.video';

  /// Generate a Nostr event link (nevent format) for a video
  String generateNostrEventLink(VideoEvent video) {
    try {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(id: video.id, author: video.pubkey),
      );
      return 'nostr:$nevent';
    } catch (e) {
      Log.error(
        'Error generating Nostr event link: $e',
        name: 'ShareService',
        category: LogCategory.system,
      );
      return video.id;
    }
  }

  /// Generate a web app link for a video.
  ///
  /// Uses the web route only when the video has a real addressable `d` tag.
  /// Otherwise falls back to a NIP-19 `nevent` link so this method never
  /// returns a broken `divine.video/video/{eventId}` URL.
  String generateWebLink(VideoEvent video) {
    if (_hasWebShareableRoute(video)) {
      return '$_appUrl/video/${video.stableId}';
    }
    return generateNostrEventLink(video);
  }

  /// Generate shareable text content.
  ///
  /// Returns only the web link so users can add their own context.
  String generateShareText(VideoEvent video) {
    return generateWebLink(video);
  }

  bool _hasWebShareableRoute(VideoEvent video) {
    final routeId = video.rawTags['d'];
    return routeId != null && routeId.isNotEmpty;
  }

  /// Copy link to clipboard
  Future<void> copyToClipboard(String text, BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareLinkCopied),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Error copying to clipboard: $e',
        name: 'ShareService',
        category: LogCategory.system,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareFailedToCopy),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Share via native platform share sheet
  Future<void> shareViaSheet(VideoEvent video, BuildContext context) async {
    try {
      final shareText = generateShareText(video);
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: context.l10n.shareVideoSubject),
      );
    } catch (e) {
      Log.error(
        'Error sharing via sheet: $e',
        name: 'ShareService',
        category: LogCategory.system,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareFailedToShare),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Show share options bottom sheet
  void showShareOptions(VideoEvent video, BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _ShareOptionsBottomSheet(video: video, shareService: this),
    );
  }
}

/// Bottom sheet widget for share options
class _ShareOptionsBottomSheet extends StatelessWidget {
  const _ShareOptionsBottomSheet({
    required this.video,
    required this.shareService,
  });
  final VideoEvent video;
  final ShareService shareService;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: VineTheme.secondaryText,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          context.l10n.shareVideoTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Share options
        _buildShareOption(
          context,
          icon: Icons.share,
          title: context.l10n.shareToApps,
          subtitle: context.l10n.shareToAppsSubtitle,
          onTap: () {
            context.pop();
            shareService.shareViaSheet(video, context);
          },
        ),

        _buildShareOption(
          context,
          icon: Icons.link,
          title: context.l10n.shareCopyWebLink,
          subtitle: context.l10n.shareCopyWebLinkSubtitle,
          onTap: () {
            context.pop();
            final webLink = shareService.generateWebLink(video);
            shareService.copyToClipboard(webLink, context);
          },
        ),

        _buildShareOption(
          context,
          icon: Icons.bolt,
          title: context.l10n.shareCopyNostrLink,
          subtitle: context.l10n.shareCopyNostrLinkSubtitle,
          onTap: () {
            context.pop();
            final nostrLink = shareService.generateNostrEventLink(video);
            shareService.copyToClipboard(nostrLink, context);
          },
        ),

        const SizedBox(height: 20),
      ],
    ),
  );

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon, size: 24),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
  );
}
