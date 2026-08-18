// ABOUTME: Shows the signed-in account's enforcement state in plain language,
// ABOUTME: with the paths to contest it and to take the account elsewhere.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/account_enforcement_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Account status surface for s-t-s#200.
///
/// Reachable from settings without a failed post, so a restricted user can
/// find out what happened rather than discovering it by failing repeatedly.
///
/// Renders from [AccountEnforcementKind] alone. Keycast also returns a
/// `suspended_reason`, but it is free text written by whatever called its
/// admin API, so it is deliberately never fetched into state or shown here.
class AccountStatusScreen extends ConsumerWidget {
  static const routeName = 'account-status';
  static const String path = RoutePaths.accountStatus;

  const AccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(accountEnforcementStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.accountStatusTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            // A failed read is not a claim about the account, so it renders the
            // same "we could not check" state as an explicit unknown rather
            // than an error page or, worse, a clean bill of health.
            error: (_, _) => _StatusBody(
              kind: AccountEnforcementKind.unknown,
              onRetry: () => ref.invalidate(accountEnforcementStatusProvider),
            ),
            data: (status) => _StatusBody(
              kind: status.kind,
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
    final isEnforced = AccountEnforcementStatus(kind: kind).isEnforced;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.accountEnforcementHeading(kind),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.accountEnforcementBody(kind),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.accountStatusRetry),
          ),
        ],
        if (isEnforced) ...[
          const SizedBox(height: 32),
          Text(
            l10n.accountStatusKeysUnaffectedHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountStatusKeysUnaffectedBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            l10n.accountStatusAppealHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountStatusAppealBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push(SupportCenterScreen.path),
            child: Text(l10n.accountStatusContactSupport),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => launchUrl(
              Uri.parse(AppConstants.accountPortabilityUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(l10n.accountStatusMoveAccount),
          ),
        ],
      ],
    );
  }
}
