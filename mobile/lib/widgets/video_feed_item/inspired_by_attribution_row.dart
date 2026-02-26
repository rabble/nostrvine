// ABOUTME: Inspired-by attribution row widget for displaying inspiration credit
// ABOUTME: on video feed items. Shows "Inspired by @DisplayName" with tap
// ABOUTME: navigation to the inspiring creator's profile.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/unified_logger.dart';

/// A tappable row showing inspired-by attribution on a video feed item.
///
/// Displays "Inspired by @DisplayName" when a video references another
/// creator's work via an `a` tag (NIP-33 addressable event) or an npub
/// reference in the content.
///
/// Tapping navigates to the inspiring creator's profile.
/// Shows nothing if the video has no inspired-by attribution.
class InspiredByAttributionRow extends ConsumerWidget {
  /// Creates an InspiredByAttributionRow.
  ///
  /// [video] must have [VideoEvent.hasInspiredBy] return true for this
  /// widget to display anything.
  const InspiredByAttributionRow({
    required this.video,
    required this.isActive,
    super.key,
  });

  /// The video event to display inspired-by attribution for.
  final VideoEvent video;

  /// Whether this video feed item is currently active (visible/playing).
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasInspiredBy) {
      return const SizedBox.shrink();
    }

    // Determine the creator pubkey from the attribution source
    final creatorPubkey = _resolveCreatorPubkey();
    if (creatorPubkey == null || creatorPubkey.isEmpty) {
      return const SizedBox.shrink();
    }

    return _InspiredByContent(creatorPubkey: creatorPubkey, isActive: isActive);
  }

  /// Resolve the creator pubkey from either inspiredByVideo or inspiredByNpub.
  String? _resolveCreatorPubkey() {
    if (video.inspiredByVideo != null) {
      return video.inspiredByVideo!.creatorPubkey;
    }
    if (video.inspiredByNpub != null) {
      try {
        return NostrKeyUtils.decode(video.inspiredByNpub!);
      } catch (e) {
        Log.warning(
          'Failed to decode inspiredByNpub '
          '${video.inspiredByNpub}: $e',
          name: 'InspiredByAttributionRow',
          category: LogCategory.ui,
        );
        return null;
      }
    }
    return null;
  }
}

/// The actual content showing inspired-by attribution.
class _InspiredByContent extends ConsumerWidget {
  const _InspiredByContent({
    required this.creatorPubkey,
    required this.isActive,
  });

  final String creatorPubkey;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final creatorProfile = userProfileService.getCachedProfile(creatorPubkey);

    // Trigger profile fetch if not cached
    if (creatorProfile == null &&
        !userProfileService.shouldSkipProfileFetch(creatorPubkey)) {
      Future.microtask(() {
        ref.read(userProfileProvider.notifier).fetchProfile(creatorPubkey);
      });
    }

    final creatorName =
        creatorProfile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(creatorPubkey);

    return GestureDetector(
      onTap: () => _navigateToCreatorProfile(context),
      child: Semantics(
        identifier: 'inspired_by_attribution_row',
        button: true,
        label: 'Inspired by $creatorName. Tap to view their profile.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Inspired by @$creatorName',
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(blurRadius: 4),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: VineTheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreatorProfile(BuildContext context) {
    Log.info(
      'Navigating to inspired-by creator profile: $creatorPubkey',
      name: 'InspiredByAttributionRow',
      category: LogCategory.ui,
    );

    final npub = normalizeToNpub(creatorPubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}
