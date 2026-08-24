// ABOUTME: Shows the signed-in account's enforcement state in plain language,
// ABOUTME: with the paths to contest it and to take the account elsewhere.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/account_enforcement_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/utils/mounted_post_frame.dart';

/// Account status surface for s-t-s#200.
///
/// Reachable from settings without a failed post, so a restricted user can
/// find out what happened rather than discovering it by failing repeatedly.
///
/// Renders from [AccountEnforcementKind] alone. Keycast also returns a
/// `suspended_reason`, but it is free text written by whatever called its
/// admin API, so it is deliberately never fetched into state or shown here.
class AccountStatusScreen extends ConsumerStatefulWidget {
  static const routeName = 'account-status';
  static const String path = RoutePaths.accountStatus;

  const AccountStatusScreen({super.key});

  @override
  ConsumerState<AccountStatusScreen> createState() =>
      _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Refetch on every visit. autoDispose alone is not enough: Settings stays
    // mounted underneath a pushed route and keeps watching
    // isAccountEnforcedProvider, so the status provider is never released and
    // would serve a value cached before the user was suspended. This is the
    // screen someone opens *to* check, so it must not show a stale answer.
    //
    // Guarded against unmount because a post-frame `ref` touch on a disposed
    // widget throws. Skipped entirely when nothing is cached yet (a cold deep
    // link), where the first watch has already started a fetch that
    // invalidating would only throw away and repeat.
    addPostFrameCallbackIfMounted(() {
      // Refetch anything already settled, success or failure alike: a first
      // fetch that failed (cold start offline) survives this screen's disposal
      // because Settings keeps the provider alive, and would otherwise render
      // stale on the next visit without ever retrying. Only an in-flight first
      // fetch is left alone, since invalidating would discard and repeat it.
      final current = ref.read(accountEnforcementStatusProvider);
      if (!current.isLoading) {
        ref.invalidate(accountEnforcementStatusProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(accountEnforcementStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.accountStatusTitle,
        showBackButton: true,
        // safePop: this screen has a registered path, so it can be reached by
        // deep link with nothing beneath it to pop back to.
        onBackPressed: () => context.safePop(fallback: SettingsScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: async.when(
            // Show the spinner while refreshing rather than Riverpod's default
            // of holding the previous value on screen. A status cached before
            // the user was suspended must not read as "in good standing" while
            // the refetch is in flight; not knowing yet is the honest state.
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            // Keep a confirmed restriction through a failed read so its appeal
            // and exit paths remain available. Never keep a stale all-clear:
            // an account may have become restricted before the failed refresh.
            error: (_, _) => _StatusBody(
              kind: async.value?.kind.isEnforced ?? false
                  ? async.value!.kind
                  : AccountEnforcementKind.unknown,
              onRetry: () => ref.invalidate(accountEnforcementStatusProvider),
            ),
            data: (status) => _StatusBody(
              kind: status.kind,
              // Retry is offered only where it can actually change the
              // answer. noAccountState is settled because there is no Divine
              // account to check.
              onRetry: status.kind == AccountEnforcementKind.unknown
                  ? () => ref.invalidate(accountEnforcementStatusProvider)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.kind, this.onRetry});

  final AccountEnforcementKind kind;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEnforced = kind.isEnforced;
    final colors = context.vineColors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.accountEnforcementHeading(kind),
          style: VineTheme.headlineSmallFont(color: colors.primaryText),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.accountEnforcementBody(kind),
          style: VineTheme.bodyMediumFont(color: colors.primaryText),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          DivineButton(
            label: l10n.accountStatusRetry,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: onRetry,
          ),
        ],
        if (isEnforced) ...[
          const SizedBox(height: 32),
          Text(
            l10n.accountStatusKeysUnaffectedHeading,
            style: VineTheme.titleMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountStatusKeysUnaffectedBody,
            style: VineTheme.bodyMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.accountStatusAppealHeading,
            style: VineTheme.titleMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountStatusAppealBody,
            style: VineTheme.bodyMediumFont(color: colors.primaryText),
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: l10n.accountStatusContactSupport,
            expanded: true,
            onPressed: () => context.push(SupportCenterScreen.path),
          ),
          const SizedBox(height: 8),
          DivineButton(
            label: l10n.accountStatusMoveAccount,
            type: DivineButtonType.secondary,
            expanded: true,
            // openExternalLink rather than a raw launchUrl: it checks the URL
            // can be handled and routes divine.video links in-app, so the exit
            // path does not silently do nothing on a device without a browser.
            onPressed: () => openExternalLink(
              context,
              AppConstants.accountPortabilityUrl,
            ),
          ),
        ],
      ],
    );
  }
}
