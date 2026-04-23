import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/user_not_available_screen.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

/// Router widget that redirects own-profile visits to ProfileScreenRouter.
/// Prevents users from accessing follow/block actions on their own profile
/// via the OtherProfileScreen route (e.g., deep links).
class OtherProfileScreenRouter extends ConsumerWidget {
  const OtherProfileScreenRouter({
    required this.npub,
    super.key,
    this.displayNameHint,
    this.avatarUrlHint,
  });

  final String npub;
  final String? displayNameHint;
  final String? avatarUrlHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(blocklistVersionProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final targetHex = npubToHexOrNull(npub);
    final currentUserHex = nostrClient.publicKey;

    final isCurrentUser =
        targetHex != null &&
        currentUserHex.isNotEmpty &&
        targetHex == currentUserHex;

    if (isCurrentUser) {
      // Redirect to own profile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(ProfileScreenRouter.pathForNpub(npub));
      });
      return const BrandedLoadingScaffold();
    }

    // If this user has blocked us, show unavailable
    if (targetHex != null) {
      final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
      if (blocklistRepository.hasBlockedUs(targetHex)) {
        return UserNotAvailableScreen(onBack: context.pop);
      }
    }

    return OtherProfileScreen(
      npub: npub,
      displayNameHint: displayNameHint,
      avatarUrlHint: avatarUrlHint,
    );
  }
}
