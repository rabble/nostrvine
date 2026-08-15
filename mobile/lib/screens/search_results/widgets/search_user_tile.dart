import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/add_to_people_lists_sheet.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Reusable tile widget for displaying a user profile in search results.
///
/// Shows avatar, display name, and a secondary line that disambiguates
/// same-named strangers: their video count when known, else the truncated
/// npub. Uses [ConsumerWidget] (Riverpod) for the feature-flag and auth
/// providers that gate the add-to-list action.
class SearchUserTile extends ConsumerWidget {
  const SearchUserTile({required this.profile, this.onTap, super.key});

  final UserProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The secondary line carries information that actually distinguishes
    // people. The claimed nip05 is unusable for that here: profile search
    // returns one identical verified handle for every same-named result (a
    // server-side archive-import data bug), and verifying it live costs one
    // HTTP fetch per row.
    final videoCount = profile.videoCount;
    final secondaryText = videoCount != null && videoCount > 0
        ? context.l10n.searchUserVideoCount(videoCount)
        : profile.truncatedNpub;

    final profileListFeaturesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileListFeatures),
    );
    // curatedLists is the master switch for people lists; profileListFeatures
    // only adds this surface on top of it. Without both, tapping would
    // construct the lazily-registered PeopleListsBloc for a disabled feature.
    final curatedListsEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final ownPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    final showAddToList =
        profileListFeaturesEnabled &&
        curatedListsEnabled &&
        profile.pubkey != ownPubkey;

    return Semantics(
      identifier: 'search_user_tile_${profile.pubkey}',
      label: profile.bestDisplayName,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            spacing: 16,
            children: [
              UserAvatar(
                imageUrl: profile.picture,
                placeholderSeed: profile.pubkey,
                size: 40,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      profile.bestDisplayName,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    Text(
                      secondaryText,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showAddToList)
                IconButton(
                  icon: DivineIcon(
                    icon: DivineIconName.listPlus,
                    color: context.vineColors.secondaryText,
                  ),
                  color: context.vineColors.secondaryText,
                  tooltip: context.l10n.peopleListsAddToList,
                  onPressed: () => AddToPeopleListsSheet.show(
                    context,
                    pubkey: profile.pubkey,
                    entryPoint: PeopleListEntryPoint.searchResult,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
