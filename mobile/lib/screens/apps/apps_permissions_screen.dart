// ABOUTME: Screen for reviewing and revoking remembered sandbox permissions
// ABOUTME: Shows per-user grant entries saved by the Nostr app grant store

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';

class AppsPermissionsScreen extends StatefulWidget {
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
  State<AppsPermissionsScreen> createState() => _AppsPermissionsScreenState();
}

class _AppsPermissionsScreenState extends State<AppsPermissionsScreen> {
  late Future<List<NostrAppGrant>> _grantsFuture;

  @override
  void initState() {
    super.initState();
    _grantsFuture = _loadGrants();
  }

  Future<List<NostrAppGrant>> _loadGrants() async {
    final userPubkey = widget.currentUserPubkey;
    if (userPubkey == null || userPubkey.isEmpty) {
      return const [];
    }

    return widget.grantStore.listGrants(userPubkey: userPubkey);
  }

  Future<void> _refreshGrants() async {
    final future = _loadGrants();
    setState(() {
      _grantsFuture = future;
    });
    await future;
  }

  Future<void> _revokeGrant(NostrAppGrant grant) async {
    final userPubkey = widget.currentUserPubkey;
    if (userPubkey == null || userPubkey.isEmpty) {
      return;
    }

    await widget.grantStore.revokeGrant(
      userPubkey: userPubkey,
      appId: grant.appId,
      origin: grant.origin,
      capability: grant.capability,
    );
    await _refreshGrants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'App permissions',
        showBackButton: true,
        onBackPressed: Navigator.of(context).pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<List<NostrAppGrant>>(
            future: _grantsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              final grants = snapshot.data ?? const <NostrAppGrant>[];
              if (grants.isEmpty) {
                return const _AppsPermissionsEmptyState();
              }

              return RefreshIndicator(
                onRefresh: _refreshGrants,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: grants.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final grant = grants[index];
                    return _GrantCard(
                      grant: grant,
                      onRevoke: () => _revokeGrant(grant),
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
              'No saved permissions',
              textAlign: TextAlign.center,
              style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              'Approved apps will appear here after you remember a sandbox grant.',
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
