import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

/// Router widget that redirects own-profile visits to ProfileScreenRouter.
/// Prevents users from accessing follow/block actions on their own profile
/// via the OtherProfileScreen route (e.g., deep links).
///
/// Also enforces blockee-side blocking: if the target user has blocked us,
/// shows an "account not available" screen instead of the profile.
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

    // Blockee-side enforcement: if this user has blocked us, show unavailable
    if (targetHex != null) {
      final blocklistService = ref.watch(contentBlocklistServiceProvider);
      if (blocklistService.hasBlockedUs(targetHex)) {
        return _BlockedByUserScreen(onBack: context.pop);
      }
    }

    return OtherProfileScreen(
      npub: npub,
      displayNameHint: displayNameHint,
      avatarUrlHint: avatarUrlHint,
    );
  }
}

/// Screen shown when the target user has blocked us.
class _BlockedByUserScreen extends StatelessWidget {
  const _BlockedByUserScreen({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                VineTheme.whiteText,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: onBack,
        ),
        title: Text(
          'Profile',
          style: VineTheme.titleFont(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icon/prohibit.svg',
                width: 48,
                height: 48,
                colorFilter: const ColorFilter.mode(
                  VineTheme.secondaryText,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Account not available',
                style: VineTheme.titleFont(color: VineTheme.primaryText),
              ),
              const SizedBox(height: 8),
              Text(
                "This account isn't available right now.",
                style: VineTheme.bodyFont(color: VineTheme.secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
