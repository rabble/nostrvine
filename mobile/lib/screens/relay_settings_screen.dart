// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure external relay preferences

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for managing Nostr relay settings
class RelaySettingsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'relay-settings';

  /// Path for this route.
  static const path = '/relay-settings';

  const RelaySettingsScreen({super.key});

  @override
  ConsumerState<RelaySettingsScreen> createState() =>
      _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends ConsumerState<RelaySettingsScreen> {
  final Map<String, RelayCapabilities?> _capabilitiesCache = {};
  final Map<String, bool> _capabilitiesLoading = {};

  Future<void> _fetchCapabilities(String relayUrl) async {
    if (_capabilitiesLoading[relayUrl] == true) return;
    if (_capabilitiesCache.containsKey(relayUrl)) return;

    setState(() {
      _capabilitiesLoading[relayUrl] = true;
    });

    try {
      final capabilityService = ref.read(relayCapabilityServiceProvider);
      final capabilities = await capabilityService.getRelayCapabilities(
        relayUrl,
      );
      if (mounted) {
        setState(() {
          _capabilitiesCache[relayUrl] = capabilities;
          _capabilitiesLoading[relayUrl] = false;
        });
      }
    } catch (e) {
      Log.debug(
        'Failed to fetch NIP-11 for $relayUrl: $e',
        name: 'RelaySettingsScreen',
      );
      if (mounted) {
        setState(() {
          _capabilitiesCache[relayUrl] = null;
          _capabilitiesLoading[relayUrl] = false;
        });
      }
    }
  }

  Future<void> _openRelayWebsite(String relayUrl) async {
    final httpUrl = relayUrl
        .replaceFirst('wss://', 'https://')
        .replaceFirst('ws://', 'http://');
    final url = Uri.parse(httpUrl);
    final couldNotOpenBrowserMessage =
        context.l10n.relaySettingsCouldNotOpenBrowser;
    final failedToOpenLinkMessage = context.l10n.relaySettingsFailedToOpenLink;
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError(couldNotOpenBrowserMessage);
      }
    } catch (e) {
      Log.error('Failed to launch relay URL: $e', name: 'RelaySettingsScreen');
      _showError(failedToOpenLinkMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final externalRelays = nostrService.configuredRelays;

    Log.info(
      'Displaying ${externalRelays.length} external relays',
      name: 'RelaySettingsScreen',
    );

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
                // Info banner with instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  color: VineTheme.cardBackground,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
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
                        style: const TextStyle(
                          color: VineTheme.lightText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _launchNostrDocs,
                        child: Text(
                          context.l10n.relaySettingsLearnMoreNostr,
                          style: const TextStyle(
                            color: VineTheme.vineGreen,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _launchNostrWatch,
                        child: Text(
                          context.l10n.relaySettingsFindPublicRelays,
                          style: const TextStyle(
                            color: VineTheme.vineGreen,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Relay list
                Expanded(
                  child: externalRelays.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
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
                                onPressed: _restoreDefaultRelay,
                                icon: const Icon(
                                  Icons.restore,
                                  color: VineTheme.whiteText,
                                ),
                                label: Text(
                                  context.l10n.relaySettingsRestoreDefaultRelay,
                                  style: const TextStyle(
                                    color: VineTheme.whiteText,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VineTheme.vineGreen,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _showAddRelayDialog,
                                icon: const Icon(
                                  Icons.add,
                                  color: VineTheme.whiteText,
                                ),
                                label: Text(
                                  context.l10n.relaySettingsAddCustomRelay,
                                  style: const TextStyle(
                                    color: VineTheme.whiteText,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VineTheme.cardBackground,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Action buttons at the top
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _showAddRelayDialog,
                                      icon: const Icon(
                                        Icons.add,
                                        color: VineTheme.whiteText,
                                      ),
                                      label: Text(
                                        context.l10n.relaySettingsAddRelay,
                                        style: const TextStyle(
                                          color: VineTheme.whiteText,
                                        ),
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
                                      onPressed: _retryConnection,
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: VineTheme.whiteText,
                                      ),
                                      label: Text(
                                        context.l10n.relaySettingsRetry,
                                        style: const TextStyle(
                                          color: VineTheme.whiteText,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            VineTheme.cardBackground,
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
                                itemCount: externalRelays.length,
                                itemBuilder: (context, index) {
                                  final relay = externalRelays[index];

                                  return _buildRelayTile(relay);
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelayTile(String relayUrl) {
    // Watch the stream provider to get reactive updates when statistics change
    final statsAsync = ref.watch(relayStatisticsStreamProvider);
    final stats = statsAsync.whenData((allStats) => allStats[relayUrl]).value;

    final isConnected = stats?.isConnected ?? false;
    final statusSummary = stats?.statusSummary ?? 'External relay';

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
              icon: const Icon(Icons.delete, color: VineTheme.error, size: 20),
              onPressed: () => _removeRelay(relayUrl),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: VineTheme.lightText, size: 20),
          ],
        ),
        iconColor: VineTheme.lightText,
        collapsedIconColor: VineTheme.lightText,
        onExpansionChanged: (expanded) {
          if (expanded) {
            _fetchCapabilities(relayUrl);
          }
        },
        children: [_buildRelayDetails(stats, relayUrl)],
      ),
    );
  }

  Widget _buildRelayDetails(RelayStatistics? stats, String relayUrl) {
    if (stats == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.relaySettingsNoStats,
          style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
        ),
      );
    }

    final capabilities = _capabilitiesCache[relayUrl];
    final isLoading = _capabilitiesLoading[relayUrl] ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            context.l10n.relaySettingsConnection,
            stats.isConnected
                ? context.l10n.relaySettingsConnected
                : context.l10n.relaySettingsDisconnected,
            stats.isConnected ? VineTheme.success : VineTheme.warning,
          ),
          if (stats.sessionDuration != null)
            _buildStatRow(
              context.l10n.relaySettingsSessionDuration,
              _formatDuration(stats.sessionDuration!),
              VineTheme.secondaryText,
            ),
          if (stats.lastConnected != null)
            _buildStatRow(
              context.l10n.relaySettingsLastConnected,
              _formatTime(stats.lastConnected!),
              VineTheme.secondaryText,
            ),
          if (!stats.isConnected && stats.lastDisconnected != null)
            _buildStatRow(
              context.l10n.relaySettingsDisconnectedLabel,
              _formatTime(stats.lastDisconnected!),
              VineTheme.warning,
            ),
          if (stats.lastDisconnectReason != null && !stats.isConnected)
            _buildStatRow(
              context.l10n.relaySettingsReason,
              stats.lastDisconnectReason!,
              VineTheme.warning,
            ),
          const Divider(color: VineTheme.lightText, height: 16),
          _buildStatRow(
            context.l10n.relaySettingsActiveSubscriptions,
            '${stats.activeSubscriptions}',
            VineTheme.info,
          ),
          _buildStatRow(
            context.l10n.relaySettingsTotalSubscriptions,
            '${stats.totalSubscriptions}',
            VineTheme.secondaryText,
          ),
          _buildStatRow(
            context.l10n.relaySettingsEventsReceived,
            _formatCount(stats.eventsReceived),
            VineTheme.success,
          ),
          _buildStatRow(
            context.l10n.relaySettingsEventsSent,
            _formatCount(stats.eventsSent),
            VineTheme.info,
          ),
          const Divider(color: VineTheme.lightText, height: 16),
          _buildStatRow(
            context.l10n.relaySettingsRequestsThisSession,
            '${stats.requestsThisSession}',
            VineTheme.secondaryText,
          ),
          _buildStatRow(
            context.l10n.relaySettingsFailedRequests,
            '${stats.failedRequests}',
            stats.failedRequests > 0
                ? VineTheme.error
                : VineTheme.secondaryText,
          ),
          if (stats.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.relaySettingsLastError(stats.lastError!),
              style: const TextStyle(color: VineTheme.error, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (stats.lastErrorTime != null)
              Text(
                _formatTime(stats.lastErrorTime!),
                style: const TextStyle(color: VineTheme.error, fontSize: 11),
              ),
          ],
          // NIP-11 Relay Info Section
          _buildRelayInfoSection(relayUrl, capabilities, isLoading),
        ],
      ),
    );
  }

  Widget _buildRelayInfoSection(
    String relayUrl,
    RelayCapabilities? capabilities,
    bool isLoading,
  ) {
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

    if (capabilities == null) {
      return const SizedBox.shrink();
    }

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
          _buildStatRow(
            context.l10n.relaySettingsSupportedNips,
            capabilities.supportedNips.join(', '),
            VineTheme.secondaryText,
          ),
        if (capabilities.rawData['software'] != null)
          _buildStatRow(
            context.l10n.relaySettingsSoftware,
            _formatSoftwareVersion(capabilities.rawData),
            VineTheme.secondaryText,
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openRelayWebsite(relayUrl),
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

  String _formatSoftwareVersion(Map<String, dynamic> rawData) {
    final software = rawData['software'] as String?;
    final version = rawData['version'] as String?;
    if (software == null) return '';
    if (version != null) {
      return '$software v$version';
    }
    return software;
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
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

  String _formatCount(int count) => CountFormatter.formatCompact(count);

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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _removeRelay(String relayUrl) async {
    // Capture l10n strings before any await to avoid
    // use_build_context_synchronously warnings.
    final failedToRemoveMessage = context.l10n.relaySettingsFailedToRemoveRelay;
    final removedRelayFn = context.l10n.relaySettingsRemovedRelay;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          context.l10n.relaySettingsRemoveRelayTitle,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          context.l10n.relaySettingsRemoveRelayMessage(relayUrl),
          style: const TextStyle(color: VineTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(
              context.l10n.relaySettingsCancel,
              style: const TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(
              context.l10n.relaySettingsRemove,
              style: const TextStyle(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final success = await nostrService.removeRelay(relayUrl);

      if (!success) {
        _showError(failedToRemoveMessage);
        return;
      }

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(removedRelayFn(relayUrl)),
            backgroundColor: VineTheme.warning,
          ),
        );
      }

      Log.info(
        'Successfully removed relay: $relayUrl',
        name: 'RelaySettingsScreen',
      );
    } catch (e) {
      Log.error('Failed to remove relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to remove relay: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: VineTheme.error),
    );
  }

  Future<void> _retryConnection() async {
    // Capture l10n strings before any await to avoid
    // use_build_context_synchronously warnings.
    final connectedToRelaysFn = context.l10n.relaySettingsConnectedToRelays;
    final failedToConnectMessage =
        context.l10n.relaySettingsFailedToConnectCheck;
    try {
      final nostrService = ref.read(nostrServiceProvider);
      final videoService = ref.read(videoEventServiceProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.relaySettingsForcingReconnection),
          backgroundColor: VineTheme.warning,
        ),
      );

      // Force reconnect all WebSocket connections to fix stale/zombie connections
      await nostrService.forceReconnectAll();

      // Check if any relays are now connected
      final connectedCount = nostrService.connectedRelayCount;

      if (connectedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(connectedToRelaysFn(connectedCount)),
              backgroundColor: VineTheme.success,
            ),
          );
        }

        // Trigger a full reset and resubscribe of all feeds
        await videoService.resetAndResubscribeAll();
      } else {
        _showError(failedToConnectMessage);
      }
    } catch (e) {
      Log.error('Failed to retry connection: $e', name: 'RelaySettingsScreen');
      _showError('Connection retry failed: $e');
    }
  }

  Future<void> _showAddRelayDialog() async {
    final controller = TextEditingController();

    // Capture l10n strings before awaits to avoid
    // use_build_context_synchronously warnings.
    final invalidUrlMessage = context.l10n.relaySettingsInvalidUrl;
    final insecureUrlMessage = context.l10n.relaySettingsInsecureUrl;
    final addedRelayFn = context.l10n.relaySettingsAddedRelay;
    final failedToAddMessage = context.l10n.relaySettingsFailedToAddRelay;

    final relayUrl = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
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
            GestureDetector(
              onTap: _launchNostrWatch,
              child: Text(
                context.l10n.relaySettingsBrowsePublicRelays,
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
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
            onPressed: () => dialogContext.pop(),
            child: Text(
              context.l10n.relaySettingsCancel,
              style: const TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                dialogContext.pop(url);
              }
            },
            child: Text(
              context.l10n.relaySettingsAdd,
              style: const TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );

    // Dispose after frame to avoid hot reload issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (relayUrl == null || relayUrl.isEmpty) return;

    // Validate URL format. Relays are WebSocket-only, so anything that
    // is not `wss://` or `ws://` (including pasted `https://` / `http://`
    // links) is structurally wrong and surfaces `relaySettingsInvalidUrl`.
    // `relaySettingsInsecureUrl` is reserved for the security-relevant
    // case: cleartext `ws://` pointed at a non-loopback host (#3362).
    final uri = Uri.tryParse(relayUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'wss' && scheme != 'ws') {
      _showError(invalidUrlMessage);
      return;
    }
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      _showError(invalidUrlMessage);
      return;
    }
    if (!isRelayUrlAllowed(relayUrl)) {
      _showError(insecureUrlMessage);
      return;
    }

    try {
      final nostrService = ref.read(nostrServiceProvider);
      final success = await nostrService.addRelay(relayUrl);

      if (success) {
        if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(addedRelayFn(relayUrl)),
              backgroundColor: VineTheme.success,
            ),
          );
        }

        Log.info(
          'Successfully added relay: $relayUrl',
          name: 'RelaySettingsScreen',
        );
      } else {
        _showError(failedToAddMessage);
      }
    } catch (e) {
      Log.error('Failed to add relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to add relay: $e');
    }
  }

  Future<void> _restoreDefaultRelay() async {
    // Capture l10n strings before the await to avoid
    // use_build_context_synchronously warnings.
    final restoredDefaultFn = context.l10n.relaySettingsRestoredDefault;
    final failedToRestoreMessage =
        context.l10n.relaySettingsFailedToRestoreDefault;
    try {
      final nostrService = ref.read(nostrServiceProvider);
      const defaultRelay = AppConstants.defaultRelayUrl;

      final success = await nostrService.addRelay(defaultRelay);

      if (success) {
        if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(restoredDefaultFn(defaultRelay)),
              backgroundColor: VineTheme.success,
            ),
          );
        }

        Log.info('Restored default relay', name: 'RelaySettingsScreen');
      } else {
        _showError(failedToRestoreMessage);
      }
    } catch (e) {
      Log.error(
        'Failed to restore default relay: $e',
        name: 'RelaySettingsScreen',
      );
      _showError('Failed to restore default relay: $e');
    }
  }

  Future<void> _launchNostrWatch() async {
    final url = Uri.parse('https://nostr.co.uk/relays/');
    final couldNotOpenBrowserMessage =
        context.l10n.relaySettingsCouldNotOpenBrowser;
    final failedToOpenLinkMessage = context.l10n.relaySettingsFailedToOpenLink;
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError(couldNotOpenBrowserMessage);
      }
    } catch (e) {
      Log.error(
        'Failed to launch nostr.co.uk: $e',
        name: 'RelaySettingsScreen',
      );
      _showError(failedToOpenLinkMessage);
    }
  }

  Future<void> _launchNostrDocs() async {
    final url = Uri.parse('https://nostr.com');
    final couldNotOpenBrowserMessage =
        context.l10n.relaySettingsCouldNotOpenBrowser;
    final failedToOpenLinkMessage = context.l10n.relaySettingsFailedToOpenLink;
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError(couldNotOpenBrowserMessage);
      }
    } catch (e) {
      Log.error('Failed to launch URL: $e', name: 'RelaySettingsScreen');
      _showError(failedToOpenLinkMessage);
    }
  }
}
