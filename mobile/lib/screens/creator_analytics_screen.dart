// ABOUTME: Creator analytics dashboard draft for profile owners.
// ABOUTME: Aggregates Funnelcake video and social metrics into creator insights.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/string_utils.dart';

/// Profile-accessible analytics dashboard for creators.
class CreatorAnalyticsScreen extends ConsumerStatefulWidget {
  const CreatorAnalyticsScreen({super.key});

  static const routeName = 'creator-analytics';
  static const path = '/creator-analytics';

  @override
  ConsumerState<CreatorAnalyticsScreen> createState() =>
      _CreatorAnalyticsScreenState();
}

class _CreatorAnalyticsScreenState
    extends ConsumerState<CreatorAnalyticsScreen> {
  late Future<_CreatorAnalyticsData> _analyticsFuture;
  _AnalyticsWindow _selectedWindow = _AnalyticsWindow.last28Days;
  bool _showDiagnostics = false;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadAnalytics();
  }

  Future<void> _refresh() async {
    setState(() {
      _analyticsFuture = _loadAnalytics();
    });
    await _analyticsFuture;
  }

  Future<_CreatorAnalyticsData> _loadAnalytics() async {
    final authService = ref.read(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) {
      throw StateError('Sign in to view creator analytics.');
    }

    final repository = ref.read(creatorAnalyticsRepositoryProvider);
    final snapshot = await repository.fetchCreatorAnalytics(pubkey);

    return _CreatorAnalyticsData(
      videos: snapshot.videos,
      socialCounts: snapshot.socialCounts,
      diagnostics: snapshot.diagnostics,
      fetchedAt: snapshot.diagnostics.fetchedAt,
    );
  }

  void _openPostAnalytics(_VideoPerformance performance) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PostAnalyticsDetailScreen(performance: performance),
      ),
    );
  }

  List<Widget> _buildOverviewSection(
    _CreatorAnalyticsSummary summary,
    _CreatorAnalyticsData data,
  ) {
    return [
      _KpiGrid(
        summary: summary,
        followerCount: data.socialCounts?.followerCount ?? 0,
      ),
      if (!summary.hasViewData) ...[
        const SizedBox(height: 12),
        _AnalyticsCard(
          title: 'View Data',
          child: Text(
            'Views are currently unavailable from the relay for these posts. '
            'Like/comment/repost metrics are still accurate.',
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
          ),
        ),
      ],
      const SizedBox(height: 16),
      _EngagementBreakdown(summary: summary),
      const SizedBox(height: 16),
      _PerformanceHighlights(
        summary: summary,
        onTapPerformance: _openPostAnalytics,
      ),
      const SizedBox(height: 16),
      _TopVideosList(summary: summary, onTapPerformance: _openPostAnalytics),
      const SizedBox(height: 16),
      _DailyTrendCard(summary: summary),
      const SizedBox(height: 16),
      _buildAudienceSnapshotCard(data),
      const SizedBox(height: 16),
      _buildRetentionCard(summary),
    ];
  }

  Widget _buildAudienceSnapshotCard(_CreatorAnalyticsData data) {
    return _AnalyticsCard(
      title: 'Audience Snapshot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Followers: ${StringUtils.formatCompactNumber(data.socialCounts?.followerCount ?? 0)}',
            style: VineTheme.bodyMediumFont(),
          ),
          const SizedBox(height: 6),
          Text(
            'Following: ${StringUtils.formatCompactNumber(data.socialCounts?.followingCount ?? 0)}',
            style: VineTheme.bodyMediumFont(),
          ),
          const SizedBox(height: 8),
          Text(
            'Audience source/geo/time breakdowns will populate as Funnelcake adds audience analytics endpoints.',
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionCard(_CreatorAnalyticsSummary summary) {
    return _AnalyticsCard(
      title: 'Retention',
      child: Text(
        summary.hasViewData
            ? 'Retention curve and watch-time breakdown will appear once per-second/per-bucket retention arrives from Funnelcake.'
            : 'Retention data unavailable until view+watch-time analytics are returned by Funnelcake.',
        style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Creator Analytics', style: VineTheme.titleFont()),
        backgroundColor: VineTheme.navGreen,
        actions: [
          IconButton(
            tooltip: 'Diagnostics',
            onPressed: () {
              setState(() {
                _showDiagnostics = !_showDiagnostics;
              });
            },
            icon: Icon(
              _showDiagnostics ? Icons.bug_report : Icons.bug_report_outlined,
            ),
          ),
        ],
      ),
      body: FutureBuilder<_CreatorAnalyticsData>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error, onRetry: _refresh);
          }

          final data = snapshot.data;
          if (data == null) {
            return _ErrorView(
              error: 'Unable to load analytics.',
              onRetry: _refresh,
            );
          }

          final summary = _CreatorAnalyticsSummary.build(
            data: data,
            window: _selectedWindow,
          );
          final useFixture = ref.watch(useFixtureCreatorAnalyticsProvider);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _RangeSelector(
                  selected: _selectedWindow,
                  onSelected: (window) {
                    setState(() {
                      _selectedWindow = window;
                    });
                  },
                ),
                if (_showDiagnostics) ...[
                  const SizedBox(height: 16),
                  _DiagnosticsPanel(
                    diagnostics: data.diagnostics,
                    useFixture: useFixture,
                    onToggleFixture: (enabled) async {
                      ref
                              .read(useFixtureCreatorAnalyticsProvider.notifier)
                              .state =
                          enabled;
                      await _refresh();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                ..._buildOverviewSection(summary, data),
                const SizedBox(height: 12),
                Text(
                  'Updated ${_formatLastUpdated(data.fetchedAt)} • '
                  'Scores use likes, comments, reposts, and views/loops from Funnelcake when available.',
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              color: VineTheme.onSurfaceMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final _AnalyticsWindow selected;
  final ValueChanged<_AnalyticsWindow> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _AnalyticsWindow.values.map((window) {
        final isSelected = window == selected;
        return ChoiceChip(
          label: Text(window.label),
          selected: isSelected,
          selectedColor: VineTheme.vineGreen.withValues(alpha: 0.2),
          labelStyle: VineTheme.bodySmallFont(
            color: isSelected ? VineTheme.whiteText : VineTheme.onSurfaceMuted,
          ),
          side: BorderSide(
            color: isSelected ? VineTheme.vineGreen : VineTheme.outlineMuted,
          ),
          onSelected: (_) => onSelected(window),
        );
      }).toList(),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({
    required this.diagnostics,
    required this.useFixture,
    required this.onToggleFixture,
  });

  final CreatorAnalyticsDiagnostics diagnostics;
  final bool useFixture;
  final ValueChanged<bool> onToggleFixture;

  @override
  Widget build(BuildContext context) {
    String sourceLabel(AnalyticsDataSource source) {
      return switch (source) {
        AnalyticsDataSource.authorVideos => 'author-videos',
        AnalyticsDataSource.bulkVideoStats => 'bulk-video-stats',
        AnalyticsDataSource.videoViewsEndpoint => 'video-views-endpoint',
      };
    }

    final sourceText = diagnostics.sourcesUsed.isEmpty
        ? 'none'
        : diagnostics.sourcesUsed.map(sourceLabel).join(', ');

    return _AnalyticsCard(
      title: 'Diagnostics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total videos: ${diagnostics.totalVideos}',
            style: VineTheme.bodySmallFont(),
          ),
          const SizedBox(height: 4),
          Text(
            'With views: ${diagnostics.videosWithAnyViews}',
            style: VineTheme.bodySmallFont(),
          ),
          const SizedBox(height: 4),
          Text(
            'Missing views: ${diagnostics.videosMissingViews}',
            style: VineTheme.bodySmallFont(),
          ),
          const SizedBox(height: 4),
          Text(
            'Hydrated (bulk): ${diagnostics.videosHydratedByBulkStats}',
            style: VineTheme.bodySmallFont(),
          ),
          const SizedBox(height: 4),
          Text(
            'Hydrated (/views): ${diagnostics.videosHydratedByViewsEndpoint}',
            style: VineTheme.bodySmallFont(),
          ),
          const SizedBox(height: 6),
          Text(
            'Sources: $sourceText',
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Use fixture data',
                  style: VineTheme.bodySmallFont(),
                ),
              ),
              Switch(
                value: useFixture,
                onChanged: onToggleFixture,
                activeThumbColor: VineTheme.vineGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary, required this.followerCount});

  final _CreatorAnalyticsSummary summary;
  final int followerCount;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = math.max((width - 48) / 2, 140.0);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          width: cardWidth,
          label: 'Videos',
          value: StringUtils.formatCompactNumber(summary.videoCount),
          icon: Icons.video_collection_outlined,
        ),
        _KpiCard(
          width: cardWidth,
          label: 'Views',
          value: summary.hasViewData
              ? StringUtils.formatCompactNumber(summary.totalViews)
              : 'N/A',
          icon: Icons.visibility_outlined,
        ),
        _KpiCard(
          width: cardWidth,
          label: 'Interactions',
          value: StringUtils.formatCompactNumber(summary.totalInteractions),
          icon: Icons.touch_app_outlined,
        ),
        _KpiCard(
          width: cardWidth,
          label: 'Engagement',
          value: summary.engagementRate == null
              ? 'N/A'
              : '${(summary.engagementRate! * 100).toStringAsFixed(1)}%',
          icon: Icons.trending_up,
        ),
        _KpiCard(
          width: cardWidth,
          label: 'Followers',
          value: StringUtils.formatCompactNumber(followerCount),
          icon: Icons.group_outlined,
        ),
        _KpiCard(
          width: cardWidth,
          label: 'Avg/Post',
          value: summary.videoCount == 0
              ? '0'
              : summary.averageInteractionsPerVideo.toStringAsFixed(1),
          icon: Icons.stacked_bar_chart,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VineTheme.vineGreen, size: 20),
          const SizedBox(height: 10),
          Text(value, style: VineTheme.titleMediumFont()),
          const SizedBox(height: 4),
          Text(
            label,
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _EngagementBreakdown extends StatelessWidget {
  const _EngagementBreakdown({required this.summary});

  final _CreatorAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalInteractions;
    final likesShare = total == 0 ? 0.0 : summary.totalLikes / total;
    final commentsShare = total == 0 ? 0.0 : summary.totalComments / total;
    final repostsShare = total == 0 ? 0.0 : summary.totalReposts / total;

    return _AnalyticsCard(
      title: 'Interaction Mix',
      child: Column(
        children: [
          _BreakdownRow(
            label: 'Likes',
            value: summary.totalLikes,
            share: likesShare,
            color: const Color(0xFF79C97D),
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            label: 'Comments',
            value: summary.totalComments,
            share: commentsShare,
            color: const Color(0xFF64B5F6),
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            label: 'Reposts',
            value: summary.totalReposts,
            share: repostsShare,
            color: const Color(0xFFFFB74D),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.share,
    required this.color,
  });

  final String label;
  final int value;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: VineTheme.bodySmallFont()),
            const Spacer(),
            Text(
              '${StringUtils.formatCompactNumber(value)} (${(share * 100).toStringAsFixed(1)}%)',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: share,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: VineTheme.outlineMuted,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

class _PerformanceHighlights extends StatelessWidget {
  const _PerformanceHighlights({
    required this.summary,
    required this.onTapPerformance,
  });

  final _CreatorAnalyticsSummary summary;
  final ValueChanged<_VideoPerformance> onTapPerformance;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Performance Highlights',
      child: Column(
        children: [
          _HighlightRow(
            label: 'Most viewed',
            title: summary.hasViewData
                ? (summary.mostViewed?.displayTitle ?? 'No videos yet')
                : 'View data unavailable',
            metricText: summary.hasViewData && summary.mostViewed != null
                ? '${StringUtils.formatCompactNumber(summary.mostViewed!.views ?? 0)} views'
                : 'N/A',
            onTap: summary.mostViewed == null
                ? null
                : () => onTapPerformance(summary.mostViewed!),
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            label: 'Most discussed',
            metricText:
                '${StringUtils.formatCompactNumber(summary.mostDiscussed?.comments ?? 0)} comments',
            title: summary.mostDiscussed?.displayTitle ?? 'No videos yet',
            onTap: summary.mostDiscussed == null
                ? null
                : () => onTapPerformance(summary.mostDiscussed!),
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            label: 'Most reposted',
            metricText:
                '${StringUtils.formatCompactNumber(summary.mostReposted?.reposts ?? 0)} reposts',
            title: summary.mostReposted?.displayTitle ?? 'No videos yet',
            onTap: summary.mostReposted == null
                ? null
                : () => onTapPerformance(summary.mostReposted!),
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.label,
    required this.metricText,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String metricText;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.bodyMediumFont(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              metricText,
              style: VineTheme.bodySmallFont(color: VineTheme.vineGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopVideosList extends StatelessWidget {
  const _TopVideosList({required this.summary, required this.onTapPerformance});

  final _CreatorAnalyticsSummary summary;
  final ValueChanged<_VideoPerformance> onTapPerformance;

  @override
  Widget build(BuildContext context) {
    final topVideos = summary.topVideos.take(5).toList();

    return _AnalyticsCard(
      title: 'Top Content',
      child: topVideos.isEmpty
          ? Text(
              'Publish a few videos to see rankings.',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.hasViewData
                      ? 'Right-side % = Engagement Rate (interactions divided by views).'
                      : 'Engagement Rate needs view data; values show as N/A until views are available.',
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 96,
                      child: Text(
                        'Engagement',
                        textAlign: TextAlign.right,
                        style: VineTheme.bodySmallFont(
                          color: VineTheme.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < topVideos.length; i++) ...[
                  _TopVideoRow(
                    rank: i + 1,
                    performance: topVideos[i],
                    onTap: () => onTapPerformance(topVideos[i]),
                  ),
                  if (i != topVideos.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _TopVideoRow extends StatelessWidget {
  const _TopVideoRow({
    required this.rank,
    required this.performance,
    required this.onTap,
  });

  final int rank;
  final _VideoPerformance performance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VineTheme.vineGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$rank', style: VineTheme.bodySmallFont()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    performance.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyMediumFont(),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${performance.views != null ? '${StringUtils.formatCompactNumber(performance.views!)} views' : 'views unavailable'} • '
                    '${StringUtils.formatCompactNumber(performance.interactions)} interactions',
                    style: VineTheme.bodySmallFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              performance.engagementRate == null
                  ? 'N/A'
                  : '${(performance.engagementRate! * 100).toStringAsFixed(1)}%',
              style: VineTheme.bodySmallFont(color: VineTheme.vineGreen),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostAnalyticsDetailScreen extends StatelessWidget {
  const _PostAnalyticsDetailScreen({required this.performance});

  final _VideoPerformance performance;

  @override
  Widget build(BuildContext context) {
    final likes = performance.likes;
    final comments = performance.comments;
    final reposts = performance.reposts;
    final total = performance.interactions;

    final likesShare = total == 0 ? 0.0 : likes / total;
    final commentsShare = total == 0 ? 0.0 : comments / total;
    final repostShare = total == 0 ? 0.0 : reposts / total;

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Post Analytics', style: VineTheme.titleFont()),
        backgroundColor: VineTheme.navGreen,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _AnalyticsCard(
            title: performance.displayTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricPill(
                      label: 'Views',
                      value: performance.views == null
                          ? 'N/A'
                          : StringUtils.formatCompactNumber(performance.views!),
                    ),
                    _MetricPill(
                      label: 'Likes',
                      value: StringUtils.formatCompactNumber(likes),
                    ),
                    _MetricPill(
                      label: 'Comments',
                      value: StringUtils.formatCompactNumber(comments),
                    ),
                    _MetricPill(
                      label: 'Reposts',
                      value: StringUtils.formatCompactNumber(reposts),
                    ),
                    _MetricPill(
                      label: 'Engagement',
                      value: performance.engagementRate == null
                          ? 'N/A'
                          : '${(performance.engagementRate! * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BreakdownRow(
                  label: 'Likes',
                  value: likes,
                  share: likesShare,
                  color: const Color(0xFF79C97D),
                ),
                const SizedBox(height: 8),
                _BreakdownRow(
                  label: 'Comments',
                  value: comments,
                  share: commentsShare,
                  color: const Color(0xFF64B5F6),
                ),
                const SizedBox(height: 8),
                _BreakdownRow(
                  label: 'Reposts',
                  value: reposts,
                  share: repostShare,
                  color: const Color(0xFFFFB74D),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: performance.video.id.isEmpty
                        ? null
                        : () {
                            context.push(
                              VideoDetailScreen.pathForId(performance.video.id),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VineTheme.whiteText,
                      side: const BorderSide(color: VineTheme.outlineMuted),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Open Post'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: VineTheme.titleSmallFont()),
          Text(
            label,
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.summary});

  final _CreatorAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final points = summary.dailyInteractions;
    final maxValue = points.fold<int>(
      0,
      (maxInteractions, point) => point.interactions > maxInteractions
          ? point.interactions
          : maxInteractions,
    );

    return _AnalyticsCard(
      title: 'Recent Daily Interactions',
      child: points.isEmpty
          ? Text(
              'No activity in this range yet.',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interactions = likes + comments + reposts by post date.',
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bar length is relative to your highest day in this window.',
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ...points.map((point) {
                  final ratio = maxValue == 0
                      ? 0.0
                      : point.interactions / maxValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 68,
                          child: Text(
                            point.axisLabel,
                            style: VineTheme.bodySmallFont(
                              color: VineTheme.onSurfaceMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: VineTheme.outlineMuted,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              VineTheme.vineGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            StringUtils.formatCompactNumber(point.interactions),
                            textAlign: TextAlign.right,
                            style: VineTheme.bodySmallFont(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VineTheme.titleSmallFont()),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _AnalyticsWindow {
  last7Days('7D', Duration(days: 7)),
  last28Days('28D', Duration(days: 28)),
  last90Days('90D', Duration(days: 90)),
  allTime('All', null);

  const _AnalyticsWindow(this.label, this.duration);

  final String label;
  final Duration? duration;
}

class _CreatorAnalyticsData {
  const _CreatorAnalyticsData({
    required this.videos,
    required this.socialCounts,
    required this.diagnostics,
    required this.fetchedAt,
  });

  final List<VideoEvent> videos;
  final SocialCounts? socialCounts;
  final CreatorAnalyticsDiagnostics diagnostics;
  final DateTime fetchedAt;
}

class _CreatorAnalyticsSummary {
  const _CreatorAnalyticsSummary({
    required this.videoCount,
    required this.totalViews,
    required this.hasViewData,
    required this.totalLikes,
    required this.totalComments,
    required this.totalReposts,
    required this.totalInteractions,
    required this.engagementRate,
    required this.averageInteractionsPerVideo,
    required this.topVideos,
    required this.dailyInteractions,
    required this.mostViewed,
    required this.mostDiscussed,
    required this.mostReposted,
  });

  final int videoCount;
  final int totalViews;
  final bool hasViewData;
  final int totalLikes;
  final int totalComments;
  final int totalReposts;
  final int totalInteractions;
  final double? engagementRate;
  final double averageInteractionsPerVideo;
  final List<_VideoPerformance> topVideos;
  final List<_DailyInteractionPoint> dailyInteractions;
  final _VideoPerformance? mostViewed;
  final _VideoPerformance? mostDiscussed;
  final _VideoPerformance? mostReposted;

  static _CreatorAnalyticsSummary build({
    required _CreatorAnalyticsData data,
    required _AnalyticsWindow window,
  }) {
    final now = DateTime.now();
    final start = window.duration == null
        ? null
        : now.subtract(window.duration!);

    final videos = data.videos.where((video) {
      if (start == null) return true;
      return !_videoTimestamp(video).isBefore(start);
    }).toList();

    final performance = videos.map(_VideoPerformance.fromVideo).toList()
      ..sort((a, b) {
        final interactionCompare = b.interactions.compareTo(a.interactions);
        if (interactionCompare != 0) return interactionCompare;
        if (a.views == null && b.views == null) return 0;
        if (a.views == null) return 1;
        if (b.views == null) return -1;
        return b.views!.compareTo(a.views!);
      });

    final likes = performance.fold<int>(0, (sum, video) => sum + video.likes);
    final comments = performance.fold<int>(
      0,
      (sum, video) => sum + video.comments,
    );
    final reposts = performance.fold<int>(
      0,
      (sum, video) => sum + video.reposts,
    );
    final interactions = likes + comments + reposts;
    final hasViewData = performance.any((video) => video.views != null);
    final views = performance.fold<int>(
      0,
      (sum, video) => sum + (video.views ?? 0),
    );
    final engagementRate = hasViewData && views > 0
        ? interactions / views
        : null;
    final avgInteractions = performance.isEmpty
        ? 0.0
        : interactions / performance.length;

    _VideoPerformance? byMetric(int Function(_VideoPerformance video) metric) {
      if (performance.isEmpty) return null;
      var best = performance.first;
      for (final video in performance.skip(1)) {
        if (metric(video) > metric(best)) {
          best = video;
        }
      }
      return best;
    }

    _VideoPerformance? byNullableMetric(
      int? Function(_VideoPerformance video) metric,
    ) {
      final withMetric = performance.where((video) => metric(video) != null);
      if (withMetric.isEmpty) return null;
      var best = withMetric.first;
      for (final video in withMetric.skip(1)) {
        final currentValue = metric(video)!;
        final bestValue = metric(best)!;
        if (currentValue > bestValue) {
          best = video;
        }
      }
      return best;
    }

    final dailyPoints = _buildDailyInteractions(
      videos,
      now: now,
      window: window,
    );

    return _CreatorAnalyticsSummary(
      videoCount: performance.length,
      totalViews: views,
      hasViewData: hasViewData,
      totalLikes: likes,
      totalComments: comments,
      totalReposts: reposts,
      totalInteractions: interactions,
      engagementRate: engagementRate,
      averageInteractionsPerVideo: avgInteractions,
      topVideos: performance,
      dailyInteractions: dailyPoints,
      mostViewed: byNullableMetric((video) => video.views),
      mostDiscussed: byMetric((video) => video.comments),
      mostReposted: byMetric((video) => video.reposts),
    );
  }

  static List<_DailyInteractionPoint> _buildDailyInteractions(
    List<VideoEvent> videos, {
    required DateTime now,
    required _AnalyticsWindow window,
  }) {
    const maxBars = 14;
    final days = switch (window) {
      _AnalyticsWindow.last7Days => 7,
      _AnalyticsWindow.last28Days => 14,
      _AnalyticsWindow.last90Days => 14,
      _AnalyticsWindow.allTime => 14,
    };
    final barDays = math.min(days, maxBars);

    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: barDays - 1));
    final byDay = <String, int>{};

    for (final video in videos) {
      final timestamp = _videoTimestamp(video);
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (day.isBefore(startDay)) continue;
      final key = _dayKey(day);
      byDay[key] =
          (byDay[key] ?? 0) + _VideoPerformance.fromVideo(video).interactions;
    }

    return List.generate(barDays, (index) {
      final day = startDay.add(Duration(days: index));
      return _DailyInteractionPoint(
        day: day,
        interactions: byDay[_dayKey(day)] ?? 0,
      );
    });
  }
}

class _VideoPerformance {
  const _VideoPerformance({
    required this.video,
    required this.views,
    required this.likes,
    required this.comments,
    required this.reposts,
    required this.interactions,
    required this.engagementRate,
    required this.displayTitle,
  });

  factory _VideoPerformance.fromVideo(VideoEvent video) {
    final likes = video.originalLikes ?? 0;
    final comments = video.originalComments ?? 0;
    final reposts = video.originalReposts ?? 0;
    final views = extractViewLikeCount(video);
    final interactions = likes + comments + reposts;
    final engagementRate = (views != null && views > 0)
        ? interactions / views
        : null;
    final displayTitle = video.title?.trim().isNotEmpty == true
        ? video.title!.trim()
        : 'Video ${video.id.substring(0, math.min(8, video.id.length))}';

    return _VideoPerformance(
      video: video,
      views: views,
      likes: likes,
      comments: comments,
      reposts: reposts,
      interactions: interactions,
      engagementRate: engagementRate,
      displayTitle: displayTitle,
    );
  }

  final VideoEvent video;
  final int? views;
  final int likes;
  final int comments;
  final int reposts;
  final int interactions;
  final double? engagementRate;
  final String displayTitle;
}

class _DailyInteractionPoint {
  const _DailyInteractionPoint({required this.day, required this.interactions});

  final DateTime day;
  final int interactions;

  String get axisLabel {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${dayLabels[day.weekday - 1]} ${day.month}/${day.day}';
  }
}

DateTime _videoTimestamp(VideoEvent video) {
  if (video.createdAt > 0) {
    return DateTime.fromMillisecondsSinceEpoch(video.createdAt * 1000);
  }
  return video.timestamp;
}

String _dayKey(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

String _formatLastUpdated(DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
