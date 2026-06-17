// ABOUTME: Developer options screen for switching between environments
// ABOUTME: Allows switching relay URLs (POC, Staging, Test, Production)
// ABOUTME: Shows page load performance timing data for debugging
// ABOUTME: Includes video format selector for A/B testing server-side formats

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:unified_logger/unified_logger.dart';

/// Returns a color indicating speed: green (<1s), orange (1-3s), red (>3s).
Color _getSpeedColor(PageLoadRecord record) {
  final ms = record.dataLoadedMs ?? record.contentVisibleMs ?? 0;
  if (ms > 3000) return VineTheme.likeRed;
  if (ms > 1000) return VineTheme.accentOrange;
  return VineTheme.vineGreen;
}

String _recordTitle(PageLoadRecord record) {
  if (record.source == PageLoadSource.route) return record.screenName;
  return '${record.screenName} (${record.source})';
}

String _recordTimingText(BuildContext context, PageLoadRecord record) {
  return context.l10n.devOptionsPageLoadVisible(
    record.contentVisibleMs?.toString() ?? '\u2014',
    record.dataLoadedMs?.toString() ?? '\u2014',
  );
}

String _recordDetailsText(BuildContext context, PageLoadRecord record) {
  final timing = _recordTimingText(context, record);
  final result = record.result;
  if (result == null) return timing;
  return '$timing | result: $result';
}

class _FormatOption {
  const _FormatOption({
    required this.format,
    required this.label,
    required this.urlPattern,
  });
  final VideoPlaybackFormat? format;
  final String label;
  final String urlPattern;
}

const _formatOptions = [
  _FormatOption(
    format: null,
    label: 'Auto (default)',
    urlPattern: 'HLS 720p/480p, 2 requests, bandwidth tracker selects quality',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.raw,
    label: 'Raw original upload',
    urlPattern: '/{hash} — 1 request, 2-16 MB/6s, 7-21 Mbps, no transcode',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.hlsMaster,
    label: 'HLS master playlist',
    urlPattern: '/{hash}/hls/master.m3u8 — 3 requests, adaptive 720p/480p',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.hls720p,
    label: 'HLS 720p stream',
    urlPattern: '/{hash}/hls/stream_720p.m3u8 — 2 requests, 1.5-2.5 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.hls480p,
    label: 'HLS 480p stream',
    urlPattern: '/{hash}/hls/stream_480p.m3u8 — 2 requests, 0.6-1 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.ts720p,
    label: 'Progressive TS 720p',
    urlPattern: '/{hash}/720p — 1 request, MPEG-TS, 1.5-2.5 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.ts480p,
    label: 'Progressive TS 480p',
    urlPattern: '/{hash}/480p — 1 request, MPEG-TS, 0.6-1 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.mp4_720p,
    label: 'Progressive MP4 720p',
    urlPattern: '/{hash}/720p.mp4 — 1 request, faststart, 1.5-2.5 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.mp4_480p,
    label: 'Progressive MP4 480p',
    urlPattern: '/{hash}/480p.mp4 — 1 request, faststart, 0.6-1 MB/6s',
  ),
];

class DeveloperOptionsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'developer-options';

  /// Path for this route.
  static const path = '/developer-options';

  const DeveloperOptionsScreen({super.key});

  @override
  ConsumerState<DeveloperOptionsScreen> createState() =>
      _DeveloperOptionsScreenState();
}

class _DeveloperOptionsScreenState
    extends ConsumerState<DeveloperOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentConfig = ref.watch(currentEnvironmentProvider);
    final reviewStatusAsync = ref.watch(
      currentMinorAccountReviewStatusProvider,
    );

    // All available environment configurations
    final environments = [
      const EnvironmentConfig(environment: AppEnvironment.production),
      const EnvironmentConfig(environment: AppEnvironment.staging),
      const EnvironmentConfig(environment: AppEnvironment.test),
      const EnvironmentConfig(environment: AppEnvironment.poc),
    ];

    final recentRecords = PageLoadHistory().getRecent(10);
    final slowestRecords = PageLoadHistory().getSlowest(5);

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: context.l10n.devOptionsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              // Environment configs
              ...environments.map((env) {
                final isSelected = env == currentConfig;
                return ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(env.indicatorColorValue),
                    ),
                  ),
                  title: Text(
                    env.displayName,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    env.relayUrl,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected
                      ? const DivineIcon(
                          icon: DivineIconName.check,
                          color: VineTheme.vineGreen,
                        )
                      : null,
                  onTap: () => _switchEnvironment(context, env, isSelected),
                );
              }),

              // Divider between environments and page load times
              const Divider(color: VineTheme.outlineVariant, height: 32),

              // Page Load Times section header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.l10n.devOptionsPageLoadTimes,
                  style: const TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Recent page load records
              if (recentRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.devOptionsNoPageLoads,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ...recentRecords.map((record) {
                  return ListTile(
                    title: Text(
                      _recordTitle(record),
                      style: const TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _recordDetailsText(context, record),
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getSpeedColor(record),
                      ),
                    ),
                  );
                }),

              // Slowest Screens subsection
              if (slowestRecords.isNotEmpty) ...[
                const Divider(color: VineTheme.outlineVariant, height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    context.l10n.devOptionsSlowestScreens,
                    style: const TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...slowestRecords.map((record) {
                  final dataMs = record.dataLoadedMs ?? 0;
                  final result = record.result == null
                      ? ''
                      : ' | result: ${record.result}';
                  return ListTile(
                    title: Text(
                      _recordTitle(record),
                      style: const TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${record.source} | data: ${dataMs}ms$result',
                      style: TextStyle(
                        color: _getSpeedColor(record),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getSpeedColor(record),
                      ),
                    ),
                  );
                }),
              ],

              const Divider(color: VineTheme.outlineVariant, height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.l10n.devOptionsVideoPlaybackFormat,
                  style: const TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              ..._formatOptions.map((option) {
                final isSelected =
                    option.format == videoFormatPreference.format;
                return ListTile(
                  title: Text(
                    option.label,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    option.urlPattern,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected
                      ? const DivineIcon(
                          icon: DivineIconName.check,
                          color: VineTheme.vineGreen,
                        )
                      : null,
                  onTap: () => _switchFormat(option.format),
                );
              }),

              if (kDebugMode) ...[
                const Divider(color: VineTheme.outlineVariant, height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    context.l10n.devOptionsMinorReviewSimulationTitle,
                    style: const TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewCurrentStateLabel,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    reviewStatusAsync.when(
                      data: (status) => status.isRestricted
                          ? context.l10n.devOptionsMinorReviewStateRestricted(
                              status.currentCase?.state.name ?? 'unknown',
                            )
                          : context.l10n.devOptionsMinorReviewStateActive,
                      loading: () =>
                          context.l10n.devOptionsMinorReviewStateLoading,
                      error: (error, stackTrace) =>
                          context.l10n.devOptionsMinorReviewStateError,
                    ),
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewClearTitle,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsMinorReviewClearSubtitle,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  onTap: _clearMinorReviewOverride,
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewTeenTitle,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsMinorReviewTeenSubtitle,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  onTap: _simulateTeenMinorReview,
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewUnder13Title,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsMinorReviewUnder13Subtitle,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  onTap: _simulateUnder13MinorReview,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchEnvironment(
    BuildContext context,
    EnvironmentConfig newConfig,
    bool isSelected,
  ) async {
    // Don't switch if already selected
    if (isSelected) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          context.l10n.devOptionsSwitchEnvironmentTitle,
          style: const TextStyle(color: VineTheme.primaryText),
        ),
        content: Text(
          context.l10n.devOptionsSwitchEnvironmentMessage(
            newConfig.displayName,
          ),
          style: const TextStyle(color: VineTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(
              context.l10n.devOptionsCancel,
              style: const TextStyle(color: VineTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            child: Text(
              context.l10n.devOptionsSwitch,
              style: const TextStyle(color: VineTheme.primaryText),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    Log.info(
      'Switching environment to ${newConfig.displayName}',
      name: 'DeveloperOptions',
      category: LogCategory.system,
    );

    // Clear in-memory video events
    final videoEventService = ref.read(videoEventServiceProvider);
    videoEventService.clearVideoEvents();

    // Switch environment (clears video cache from DB and updates config)
    await switchEnvironment(ref, newConfig);

    Log.info(
      'Environment switched to ${newConfig.displayName}',
      name: 'DeveloperOptions',
      category: LogCategory.system,
    );

    // Show confirmation and go back
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.devOptionsSwitchedTo(newConfig.displayName),
          ),
          backgroundColor: Color(newConfig.indicatorColorValue),
        ),
      );
      context.pop();
    }
  }

  Future<void> _switchFormat(VideoPlaybackFormat? format) async {
    await videoFormatPreference.setFormat(format);
    await openVineMediaCache.clearCache();

    final videoEventService = ref.read(videoEventServiceProvider);
    videoEventService.clearVideoEvents();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.devOptionsSwitchedFormat(
            format?.name ?? 'HLS (default)',
          ),
        ),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
  }

  Future<void> _clearMinorReviewOverride() async {
    final service = ref.read(minorAccountReviewOverrideServiceProvider);
    await service.clearOverride();
    ref.invalidate(currentMinorAccountReviewStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.devOptionsMinorReviewClearedToast),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
    setState(() {});
  }

  Future<void> _simulateTeenMinorReview() async {
    final l10n = context.l10n;
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    final moderationPubkey = ref
        .read(moderationLabelServiceProvider)
        .divineModerationPubkeyHex;

    final override = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
      currentCase: MinorReviewCase(
        id: 'sim-teen-review',
        state: MinorReviewCaseState.restrictedPendingUserResponse,
        suspectedAgeBand: SuspectedAgeBand.age13To15,
        allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
        instructions: MinorReviewInstructions(
          title: l10n.minorAccountReviewDefaultTitle,
          body: l10n.minorAccountReviewDefaultBody,
        ),
        supportEmail: AppConstants.supportEmail,
        moderationConversationPubkey: moderationPubkey,
        moderationConversationId: currentPubkey == null
            ? null
            : DmRepository.computeConversationId([
                currentPubkey,
                moderationPubkey,
              ]),
      ),
    );

    await ref
        .read(minorAccountReviewOverrideServiceProvider)
        .setOverride(override);
    ref.invalidate(currentMinorAccountReviewStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.devOptionsMinorReviewTeenEnabledToast),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
    setState(() {});
  }

  Future<void> _simulateUnder13MinorReview() async {
    final l10n = context.l10n;
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    final moderationPubkey = ref
        .read(moderationLabelServiceProvider)
        .divineModerationPubkeyHex;

    final override = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
      currentCase: MinorReviewCase(
        id: 'sim-under13-review',
        state: MinorReviewCaseState.restrictedPendingSupportEmail,
        suspectedAgeBand: SuspectedAgeBand.under13,
        allowedResolution: MinorReviewResolutionType.supportEmailOnly,
        instructions: MinorReviewInstructions(
          title: l10n.minorAccountReviewUnder13SupportTitle,
          body: l10n.minorAccountReviewUnder13Heading,
        ),
        supportEmail: AppConstants.supportEmail,
        moderationConversationPubkey: moderationPubkey,
        moderationConversationId: currentPubkey == null
            ? null
            : DmRepository.computeConversationId([
                currentPubkey,
                moderationPubkey,
              ]),
      ),
    );

    await ref
        .read(minorAccountReviewOverrideServiceProvider)
        .setOverride(override);
    ref.invalidate(currentMinorAccountReviewStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.devOptionsMinorReviewUnder13EnabledToast),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
    setState(() {});
  }
}
