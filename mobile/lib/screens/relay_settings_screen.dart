// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure external relay preferences

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_cubit.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page: bridges the NostrClient + RelayCapabilityService + VideoEventService
/// into [RelaySettingsCubit].
class RelaySettingsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'relay-settings';

  /// Path for this route.
  static const path = '/relay-settings';

  const RelaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrService = ref.watch(nostrServiceProvider);
    final capabilityService = ref.watch(relayCapabilityServiceProvider);
    final videoService = ref.watch(videoEventServiceProvider);
    return BlocProvider(
      key: ValueKey((nostrService, capabilityService, videoService)),
      create: (_) => RelaySettingsCubit(
        nostrClient: nostrService,
        relayCapabilityService: capabilityService,
        videoEventService: videoService,
      )..load(),
      child: const RelaySettingsView(),
    );
  }
}

/// View: renders the relay list + per-relay stats + capability info from
/// Cubit state. Stats come from the existing reactive Riverpod stream
/// provider — the Cubit only owns the configured-relay snapshot and the
/// capability cache.
class RelaySettingsView extends StatelessWidget {
  @visibleForTesting
  const RelaySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.relaySettingsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const _InfoBanner(),
                Expanded(
                  child:
                      BlocSelector<
                        RelaySettingsCubit,
                        RelaySettingsState,
                        List<String>
                      >(
                        selector: (state) => state.relays,
                        builder: (context, relays) {
                          Log.info(
                            'Displaying ${relays.length} external relays',
                            name: 'RelaySettingsScreen',
                          );
                          return relays.isEmpty
                              ? const _EmptyRelayList()
                              : _RelayList(relays: relays);
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: VineTheme.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.info,
                color: VineTheme.lightText,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.relaySettingsInfoTitle,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.relaySettingsInfoDescription,
            style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: context.l10n.relaySettingsLearnMoreNostr,
            child: GestureDetector(
              onTap: () =>
                  _launchExternalUrl(context, Uri.parse('https://nostr.com')),
              child: Text(
                context.l10n.relaySettingsLearnMoreNostr,
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            button: true,
            label: context.l10n.relaySettingsFindPublicRelays,
            child: GestureDetector(
              onTap: () => _launchExternalUrl(
                context,
                Uri.parse('https://nostr.co.uk/relays/'),
              ),
              child: Text(
                context.l10n.relaySettingsFindPublicRelays,
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRelayList extends StatelessWidget {
  const _EmptyRelayList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.warning,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.relaySettingsAppNotFunctional,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.relaySettingsRequiresRelay,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _restoreDefaultRelay(context),
            icon: const DivineIcon(
              icon: DivineIconName.arrowCounterClockwise,
              color: VineTheme.whiteText,
            ),
            label: Text(
              context.l10n.relaySettingsRestoreDefaultRelay,
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddRelayDialog(context),
            icon: const DivineIcon(
              icon: DivineIconName.plus,
              color: VineTheme.whiteText,
            ),
            label: Text(
              context.l10n.relaySettingsAddCustomRelay,
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelayList extends StatelessWidget {
  const _RelayList({required this.relays});

  final List<String> relays;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddRelayDialog(context),
                  icon: const DivineIcon(
                    icon: DivineIconName.plus,
                    color: VineTheme.whiteText,
                  ),
                  label: Text(
                    context.l10n.relaySettingsAddRelay,
                    style: const TextStyle(color: VineTheme.whiteText),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _retryConnection(context),
                  icon: const DivineIcon(
                    icon: DivineIconName.arrowClockwise,
                    color: VineTheme.whiteText,
                  ),
                  label: Text(
                    context.l10n.relaySettingsRetry,
                    style: const TextStyle(color: VineTheme.whiteText),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.cardBackground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: relays.length,
            itemBuilder: (context, index) =>
                _RelayTile(relayUrl: relays[index]),
          ),
        ),
      ],
    );
  }
}

class _RelayTile extends ConsumerWidget {
  const _RelayTile({required this.relayUrl});

  final String relayUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(relayStatisticsStreamProvider);
    final stats = statsAsync.whenData((allStats) => allStats[relayUrl]).value;
    final isConnected = stats?.isConnected ?? false;
    final statusSummary = _relayStatusSummary(context, stats);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: VineTheme.transparent),
      child: ExpansionTile(
        leading: Icon(
          isConnected ? Icons.cloud_done : Icons.cloud_off,
          color: isConnected ? VineTheme.success : VineTheme.warning,
          size: 20,
        ),
        title: Text(
          relayUrl,
          style: const TextStyle(color: VineTheme.whiteText, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          statusSummary,
          style: TextStyle(
            color: isConnected ? VineTheme.lightText : VineTheme.warning,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const DivineIcon(
                icon: DivineIconName.trash,
                color: VineTheme.error,
                size: 20,
              ),
              onPressed: () => _confirmRemoveRelay(context, relayUrl),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const DivineIcon(
              icon: DivineIconName.caretDown,
              color: VineTheme.lightText,
              size: 20,
            ),
          ],
        ),
        iconColor: VineTheme.lightText,
        collapsedIconColor: VineTheme.lightText,
        onExpansionChanged: (expanded) {
          if (expanded) {
            context.read<RelaySettingsCubit>().fetchCapabilities(relayUrl);
          }
        },
        children: [_RelayDetails(stats: stats, relayUrl: relayUrl)],
      ),
    );
  }
}

class _RelayDetails extends StatelessWidget {
  const _RelayDetails({required this.stats, required this.relayUrl});

  final RelayStatistics? stats;
  final String relayUrl;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.relaySettingsNoStats,
          style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
        ),
      );
    }
    final entry = context.select(
      (RelaySettingsCubit cubit) => cubit.state.capabilities[relayUrl],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(
            label: context.l10n.relaySettingsConnection,
            value: stats!.isConnected
                ? context.l10n.relaySettingsConnected
                : context.l10n.relaySettingsDisconnected,
            valueColor: stats!.isConnected
                ? VineTheme.success
                : VineTheme.warning,
          ),
          if (stats!.sessionDuration != null)
            _StatRow(
              label: context.l10n.relaySettingsSessionDuration,
              value: _formatDuration(stats!.sessionDuration!),
              valueColor: VineTheme.secondaryText,
            ),
          if (stats!.lastConnected != null)
            _StatRow(
              label: context.l10n.relaySettingsLastConnected,
              value: _formatTime(context, stats!.lastConnected!),
              valueColor: VineTheme.secondaryText,
            ),
          if (!stats!.isConnected && stats!.lastDisconnected != null)
            _StatRow(
              label: context.l10n.relaySettingsDisconnectedLabel,
              value: _formatTime(context, stats!.lastDisconnected!),
              valueColor: VineTheme.warning,
            ),
          if (stats!.lastDisconnectReason != null && !stats!.isConnected)
            _StatRow(
              label: context.l10n.relaySettingsReason,
              value: stats!.lastDisconnectReason!,
              valueColor: VineTheme.warning,
            ),
          const Divider(color: VineTheme.lightText, height: 16),
          _StatRow(
            label: context.l10n.relaySettingsActiveSubscriptions,
            value: '${stats!.activeSubscriptions}',
            valueColor: VineTheme.info,
          ),
          _StatRow(
            label: context.l10n.relaySettingsTotalSubscriptions,
            value: '${stats!.totalSubscriptions}',
            valueColor: VineTheme.secondaryText,
          ),
          _StatRow(
            label: context.l10n.relaySettingsEventsReceived,
            value: CountFormatter.formatCompact(stats!.eventsReceived),
            valueColor: VineTheme.success,
          ),
          _StatRow(
            label: context.l10n.relaySettingsEventsSent,
            value: CountFormatter.formatCompact(stats!.eventsSent),
            valueColor: VineTheme.info,
          ),
          const Divider(color: VineTheme.lightText, height: 16),
          _StatRow(
            label: context.l10n.relaySettingsRequestsThisSession,
            value: '${stats!.requestsThisSession}',
            valueColor: VineTheme.secondaryText,
          ),
          _StatRow(
            label: context.l10n.relaySettingsFailedRequests,
            value: '${stats!.failedRequests}',
            valueColor: stats!.failedRequests > 0
                ? VineTheme.error
                : VineTheme.secondaryText,
          ),
          if (stats!.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.relaySettingsLastError(stats!.lastError!),
              style: const TextStyle(color: VineTheme.error, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (stats!.lastErrorTime != null)
              Text(
                _formatTime(context, stats!.lastErrorTime!),
                style: const TextStyle(color: VineTheme.error, fontSize: 11),
              ),
          ],
          _RelayInfoSection(relayUrl: relayUrl, entry: entry),
        ],
      ),
    );
  }
}

class _RelayInfoSection extends StatelessWidget {
  const _RelayInfoSection({required this.relayUrl, required this.entry});

  final String relayUrl;
  final RelayCapabilityEntry? entry;

  @override
  Widget build(BuildContext context) {
    final isLoading = entry?.loading ?? false;
    final capabilities = entry?.capabilities;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: VineTheme.lightText, height: 24),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.vineGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.relaySettingsLoadingRelayInfo,
                style: const TextStyle(
                  color: VineTheme.lightText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (capabilities == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: VineTheme.lightText, height: 24),
        Text(
          context.l10n.relaySettingsAboutRelay,
          style: const TextStyle(
            color: VineTheme.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (capabilities.name != null && capabilities.name!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              capabilities.name!,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (capabilities.description != null &&
            capabilities.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              capabilities.description!,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
        if (capabilities.supportedNips.isNotEmpty)
          _StatRow(
            label: context.l10n.relaySettingsSupportedNips,
            value: capabilities.supportedNips.join(', '),
            valueColor: VineTheme.secondaryText,
          ),
        if (capabilities.rawData['software'] != null)
          _StatRow(
            label: context.l10n.relaySettingsSoftware,
            value: _formatSoftwareVersion(capabilities.rawData),
            valueColor: VineTheme.secondaryText,
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openRelayWebsite(context, relayUrl),
          icon: const Icon(
            Icons.open_in_new,
            size: 16,
            color: VineTheme.whiteText,
          ),
          label: Text(
            context.l10n.relaySettingsViewWebsite,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.cardBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
          ),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Add-relay dialog. The `TextEditingController` lives in this widget per
/// the hybrid pattern (controllers are UI plumbing, not Cubit state).
class _AddRelayDialog extends StatefulWidget {
  const _AddRelayDialog();

  @override
  State<_AddRelayDialog> createState() => _AddRelayDialogState();
}

class _AddRelayDialogState extends State<_AddRelayDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        context.l10n.relaySettingsAddRelayTitle,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.relaySettingsAddRelayPrompt,
            style: const TextStyle(color: VineTheme.lightText),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: context.l10n.relaySettingsBrowsePublicRelays,
            child: GestureDetector(
              onTap: () => _launchExternalUrl(
                context,
                Uri.parse('https://nostr.co.uk/relays/'),
              ),
              child: Text(
                context.l10n.relaySettingsBrowsePublicRelays,
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              hintText: 'wss://relay.example.com',
              hintStyle: TextStyle(color: VineTheme.lightText),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.cardBackground),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.vineGreen),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.l10n.relaySettingsCancel,
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        TextButton(
          onPressed: () {
            final url = _controller.text.trim();
            if (url.isNotEmpty) Navigator.pop(context, url);
          },
          child: Text(
            context.l10n.relaySettingsAdd,
            style: const TextStyle(color: VineTheme.vineGreen),
          ),
        ),
      ],
    );
  }
}

// Action helpers — pulled to top-level functions so the private widget
// classes can share them without each having to be a ConsumerWidget /
// reach into a parent state.

Future<void> _showAddRelayDialog(BuildContext context) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final relayUrl = await showDialog<String>(
    context: context,
    builder: (_) => const _AddRelayDialog(),
  );
  if (relayUrl == null || relayUrl.isEmpty) return;

  final outcome = await cubit.addRelay(relayUrl);
  switch (outcome) {
    case AddRelayOutcome.added:
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.relaySettingsAddedRelay(relayUrl)),
          backgroundColor: VineTheme.success,
        ),
      );
      Log.info(
        'Successfully added relay: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case AddRelayOutcome.invalidUrl:
      _showError(messenger, l10n.relaySettingsInvalidUrl);
    case AddRelayOutcome.insecureUrl:
      _showError(messenger, l10n.relaySettingsInsecureUrl);
    case AddRelayOutcome.failed:
      _showError(messenger, l10n.relaySettingsFailedToAddRelay);
  }
}

Future<void> _confirmRemoveRelay(BuildContext context, String relayUrl) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        l10n.relaySettingsRemoveRelayTitle,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: Text(
        l10n.relaySettingsRemoveRelayMessage(relayUrl),
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            l10n.relaySettingsCancel,
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            l10n.relaySettingsRemove,
            style: const TextStyle(color: VineTheme.error),
          ),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  final outcome = await cubit.removeRelay(relayUrl);
  switch (outcome) {
    case RemoveRelayOutcome.removed:
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.relaySettingsRemovedRelay(relayUrl)),
          backgroundColor: VineTheme.warning,
        ),
      );
      Log.info(
        'Successfully removed relay: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    case RemoveRelayOutcome.failed:
      _showError(messenger, l10n.relaySettingsFailedToRemoveRelay);
  }
}

Future<void> _retryConnection(BuildContext context) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.relaySettingsForcingReconnection),
      backgroundColor: VineTheme.warning,
    ),
  );

  final outcome = await cubit.retryConnection();
  switch (outcome.kind) {
    case RetryConnectionOutcomeKind.connected:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.relaySettingsConnectedToRelays(outcome.connectedCount),
          ),
          backgroundColor: VineTheme.success,
        ),
      );
    case RetryConnectionOutcomeKind.notConnected:
    case RetryConnectionOutcomeKind.failed:
      _showError(messenger, l10n.relaySettingsFailedToConnectCheck);
  }
}

Future<void> _restoreDefaultRelay(BuildContext context) async {
  final cubit = context.read<RelaySettingsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  final outcome = await cubit.restoreDefaultRelay();
  switch (outcome) {
    case RestoreDefaultRelayOutcome.restored:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.relaySettingsRestoredDefault(cubit.defaultRelayUrl),
          ),
          backgroundColor: VineTheme.success,
        ),
      );
      Log.info('Restored default relay', name: 'RelaySettingsScreen');
    case RestoreDefaultRelayOutcome.failed:
      _showError(messenger, l10n.relaySettingsFailedToRestoreDefault);
  }
}

Future<void> _openRelayWebsite(BuildContext context, String relayUrl) async {
  final httpUrl = relayUrl
      .replaceFirst('wss://', 'https://')
      .replaceFirst('ws://', 'http://');
  await _launchExternalUrl(context, Uri.parse(httpUrl));
}

Future<void> _launchExternalUrl(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.of(context);
  final couldNotOpenBrowserMessage =
      context.l10n.relaySettingsCouldNotOpenBrowser;
  final failedToOpenLinkMessage = context.l10n.relaySettingsFailedToOpenLink;
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showError(messenger, couldNotOpenBrowserMessage);
    }
  } catch (e) {
    Log.error('Failed to launch URL: $e', name: 'RelaySettingsScreen');
    _showError(messenger, failedToOpenLinkMessage);
  }
}

void _showError(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: VineTheme.error),
  );
}

String _formatSoftwareVersion(Map<String, dynamic> rawData) {
  final software = rawData['software'] as String?;
  final version = rawData['version'] as String?;
  if (software == null) return '';
  if (version != null) return '$software v$version';
  return software;
}

String _relayStatusSummary(BuildContext context, RelayStatistics? stats) {
  if (stats == null) return context.l10n.relaySettingsExternalRelay;
  if (!stats.isConnected) {
    if (stats.lastDisconnected != null) {
      final ago = DateTime.now().difference(stats.lastDisconnected!);
      return context.l10n.relaySettingsDisconnectedAgo(_formatDuration(ago));
    }
    return context.l10n.relaySettingsNotConnected;
  }

  final parts = <String>[];
  if (stats.activeSubscriptions > 0) {
    parts.add(
      context.l10n.relaySettingsSubscriptionsSummary(stats.activeSubscriptions),
    );
  }
  if (stats.eventsReceived > 0) {
    parts.add(
      context.l10n.relaySettingsEventsSummary(
        CountFormatter.formatCompact(stats.eventsReceived),
      ),
    );
  }
  if (parts.isEmpty) return context.l10n.relaySettingsConnected;
  return parts.join(' | ');
}

String _formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  } else if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  } else if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  } else {
    return '${duration.inSeconds}s';
  }
}

String _formatTime(BuildContext context, DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) {
    return context.l10n.relaySettingsTimeAgo('${diff.inSeconds}s');
  } else if (diff.inMinutes < 60) {
    return context.l10n.relaySettingsTimeAgo('${diff.inMinutes}m');
  } else if (diff.inHours < 24) {
    return context.l10n.relaySettingsTimeAgo('${diff.inHours}h');
  } else {
    return context.l10n.relaySettingsTimeAgo('${diff.inDays}d');
  }
}
