// ABOUTME: Developer options screen for switching between environments
// ABOUTME: Allows switching relay URLs (POC, Staging, Test, Production)
// ABOUTME: Shows page load performance timing data for debugging
// ABOUTME: Includes video format selector for A/B testing server-side formats

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/page_load_history.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:unified_logger/unified_logger.dart';

/// Returns a color indicating speed: green (<1s), orange (1-3s), red (>3s).
Color _getSpeedColor(PageLoadRecord record) {
  final ms = record.dataLoadedMs ?? record.contentVisibleMs ?? 0;
  if (ms > 3000) return VineTheme.likeRed;
  if (ms > 1000) return VineTheme.accentOrange;
  return VineTheme.vineGreen;
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
        title: 'Developer Options',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: ListView(
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
                  ? const Icon(Icons.check, color: VineTheme.vineGreen)
                  : null,
              onTap: () => _switchEnvironment(context, env, isSelected),
            );
          }),

          // Divider between environments and page load times
          const Divider(color: VineTheme.outlineVariant, height: 32),

          // Page Load Times section header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Page Load Times',
              style: TextStyle(
                color: VineTheme.vineGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Recent page load records
          if (recentRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No page loads recorded yet.\n'
                'Navigate around the app to see timing data.',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
            )
          else
            ...recentRecords.map((record) {
              return ListTile(
                title: Text(
                  record.screenName,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Visible: ${record.contentVisibleMs ?? "\u2014"}ms'
                  '  |  '
                  'Data: ${record.dataLoadedMs ?? "\u2014"}ms',
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Slowest Screens',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...slowestRecords.map((record) {
              final dataMs = record.dataLoadedMs ?? 0;
              return ListTile(
                title: Text(
                  record.screenName,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${dataMs}ms',
                  style: TextStyle(color: _getSpeedColor(record), fontSize: 12),
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

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Video Playback Format',
              style: TextStyle(
                color: VineTheme.vineGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ..._formatOptions.map((option) {
            final isSelected = option.format == videoFormatPreference.format;
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
                  ? const Icon(Icons.check, color: VineTheme.vineGreen)
                  : null,
              onTap: () => _switchFormat(option.format),
            );
          }),
        ],
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
        title: const Text(
          'Switch Environment?',
          style: TextStyle(color: VineTheme.primaryText),
        ),
        content: Text(
          'Switch to ${newConfig.displayName}?\n\n'
          'This will clear cached video data and reconnect to the new relay.',
          style: const TextStyle(color: VineTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            child: const Text(
              'Switch',
              style: TextStyle(color: VineTheme.primaryText),
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
          content: Text('Switched to ${newConfig.displayName}'),
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
          'Switched to ${format?.name ?? "HLS (default)"} — cache cleared',
        ),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
  }
}
