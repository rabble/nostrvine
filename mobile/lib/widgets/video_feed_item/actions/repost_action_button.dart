// ABOUTME: Repost action button for video feed overlay.
// ABOUTME: Displays repost icon with count, handles toggle repost action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';

/// Repost action button with count display for video overlay.
///
/// Shows a repost icon that toggles the repost state.
/// Uses addressable ID for proper repost state tracking.
class RepostActionButton extends ConsumerWidget {
  const RepostActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialState = ref.watch(socialProvider);

    // Construct addressable ID for repost state check
    final dTag = video.rawTags['d'];
    final addressableId = dTag != null
        ? '${NIP71VideoKinds.addressableShortVideo}:${video.pubkey}:$dTag'
        : video.id;
    final isReposted = socialState.hasReposted(addressableId);
    final isRepostInProgress = socialState.isRepostInProgress(video.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'repost_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: isReposted ? 'Remove repost' : 'Repost video',
          child: CircularIconButton(
            onPressed: isRepostInProgress
                ? () {}
                : () async {
                    Log.info(
                      '🔁 Repost button tapped for ${video.id}',
                      name: 'RepostActionButton',
                      category: LogCategory.ui,
                    );
                    await ref.read(socialProvider.notifier).toggleRepost(video);
                  },
            icon: isRepostInProgress
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.repeat,
                    color: isReposted ? VineTheme.vineGreen : Colors.white,
                    size: 32,
                  ),
          ),
        ),
        // Show repost count: Nostr reposts + original reposts (if any)
        Builder(
          builder: (context) {
            final nostrReposts = video.reposterPubkeys?.length ?? 0;
            final originalReposts = video.originalReposts ?? 0;
            final totalReposts = nostrReposts + originalReposts;

            if (totalReposts > 0) {
              return Padding(
                padding: EdgeInsets.zero,
                child: Text(
                  StringUtils.formatCompactNumber(totalReposts),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 6,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
