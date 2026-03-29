// ABOUTME: Screen for reviewing and revoking remembered integration permissions
// ABOUTME: Shows per-user grant entries saved by the Nostr app grant store

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/apps/apps_permissions_cubit.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';

class AppsPermissionsScreen extends StatelessWidget {
  static const routeName = 'apps-permissions';
  static const path = '/apps/permissions';

  const AppsPermissionsScreen({
    required this.grantStore,
    required this.currentUserPubkey,
    super.key,
  });

  final NostrAppGrantStore grantStore;
  final String? currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(currentUserPubkey ?? ''),
      create: (_) => AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: currentUserPubkey,
      )..load(),
      child: const _AppsPermissionsView(),
    );
  }
}

class _AppsPermissionsView extends StatelessWidget {
  const _AppsPermissionsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Integration Permissions',
        showBackButton: true,
        onBackPressed: Navigator.of(context).pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<AppsPermissionsCubit, AppsPermissionsState>(
            builder: (context, state) {
              if (state.status != AppsPermissionsStatus.loaded) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.grants.isEmpty) {
                return const _AppsPermissionsEmptyState();
              }

              return RefreshIndicator(
                onRefresh: context.read<AppsPermissionsCubit>().load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.grants.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final grant = state.grants[index];
                    return _GrantCard(
                      grant: grant,
                      onRevoke: () => context
                          .read<AppsPermissionsCubit>()
                          .revokeGrant(grant),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppsPermissionsEmptyState extends StatelessWidget {
  const _AppsPermissionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              color: VineTheme.vineGreen,
              size: 28,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved integration permissions',
              textAlign: TextAlign.center,
              style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              'Approved integrations will appear here after you remember an access approval.',
              textAlign: TextAlign.center,
              style: VineTheme.bodyLargeFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({
    required this.grant,
    required this.onRevoke,
  });

  final NostrAppGrant grant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grant.appId,
            style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            grant.origin,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            grant.capability,
            style: VineTheme.bodyMediumFont(color: VineTheme.vineGreen),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: DivineButton(
              label: 'Revoke',
              onPressed: onRevoke,
            ),
          ),
        ],
      ),
    );
  }
}
