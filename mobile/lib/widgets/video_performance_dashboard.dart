// ABOUTME: Performance monitoring dashboard widget for video system analytics
// ABOUTME: Provides real-time visualization of memory usage, alerts, and performance metrics

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/video_performance_monitor.dart';
import '../services/video_manager_interface.dart';

/// Performance monitoring dashboard for video system
/// 
/// This widget provides comprehensive visualization of video system performance,
/// including real-time metrics, alerts, trends, and recommendations.
class VideoPerformanceDashboard extends StatelessWidget {
  final bool showAdvancedMetrics;
  final Duration refreshInterval;
  
  const VideoPerformanceDashboard({
    super.key,
    this.showAdvancedMetrics = false,
    this.refreshInterval = const Duration(seconds: 5),
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<VideoPerformanceMonitor>(
      builder: (context, monitor, child) {
        final statistics = monitor.getStatistics();
        final analytics = monitor.getAnalytics(timeRange: const Duration(hours: 1));
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Video Performance'),
            actions: [
              IconButton(
                icon: Icon(monitor.isMonitoring ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (monitor.isMonitoring) {
                    monitor.stopMonitoring();
                  } else {
                    monitor.startMonitoring();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => monitor.clearData(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              // Trigger a refresh by collecting a new sample
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Overview
                  _buildStatusOverview(context, statistics, monitor),
                  const SizedBox(height: 24),
                  
                  // Active Alerts
                  if (monitor.activeAlerts.isNotEmpty) ...[
                    _buildAlertsSection(context, monitor.activeAlerts),
                    const SizedBox(height: 24),
                  ],
                  
                  // Key Metrics
                  _buildKeyMetrics(context, statistics),
                  const SizedBox(height: 24),
                  
                  // Memory Usage Analysis
                  _buildMemoryAnalysis(context, analytics.memoryUsage),
                  const SizedBox(height: 24),
                  
                  // Preload Performance
                  _buildPreloadAnalysis(context, analytics.preloadPerformance),
                  const SizedBox(height: 24),
                  
                  // Error Analysis
                  if (analytics.errorAnalysis.totalErrors > 0) ...[
                    _buildErrorAnalysis(context, analytics.errorAnalysis),
                    const SizedBox(height: 24),
                  ],
                  
                  // Recommendations
                  if (analytics.recommendations.isNotEmpty) ...[
                    _buildRecommendations(context, analytics.recommendations),
                    const SizedBox(height: 24),
                  ],
                  
                  // Advanced Metrics (if enabled)
                  if (showAdvancedMetrics) ...[
                    _buildAdvancedMetrics(context, statistics, analytics),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusOverview(BuildContext context, PerformanceStatistics stats, VideoPerformanceMonitor monitor) {
    final theme = Theme.of(context);
    final isHealthy = stats.currentMemoryMB < 500 && stats.preloadSuccessRate > 0.9;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHealthy ? Icons.check_circle : Icons.warning,
                  color: isHealthy ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Status',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHealthy ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isHealthy ? 'HEALTHY' : 'WARNING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusMetric(
                    'Monitoring',
                    monitor.isMonitoring ? 'Active' : 'Inactive',
                    monitor.isMonitoring ? Colors.green : Colors.grey,
                    Icons.monitor_heart,
                  ),
                ),
                Expanded(
                  child: _buildStatusMetric(
                    'Memory',
                    '${stats.currentMemoryMB}MB',
                    stats.currentMemoryMB < 500 ? Colors.green : Colors.orange,
                    Icons.memory,
                  ),
                ),
                Expanded(
                  child: _buildStatusMetric(
                    'Success Rate',
                    '${(stats.preloadSuccessRate * 100).toStringAsFixed(1)}%',
                    stats.preloadSuccessRate > 0.9 ? Colors.green : Colors.orange,
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusMetric(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildAlertsSection(BuildContext context, List<PerformanceAlert> alerts) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text('Active Alerts', style: theme.textTheme.titleLarge),
                const Spacer(),
                Chip(
                  label: Text('${alerts.length}'),
                  backgroundColor: Colors.red.shade100,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.take(5).map((alert) => _buildAlertItem(context, alert)),
            if (alerts.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${alerts.length - 5} more alerts',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlertItem(BuildContext context, PerformanceAlert alert) {
    final color = switch (alert.severity) {
      AlertSeverity.critical => Colors.red,
      AlertSeverity.warning => Colors.orange,
      AlertSeverity.info => Colors.blue,
    };
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatTimestamp(alert.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final monitor = context.read<VideoPerformanceMonitor>();
              monitor.dismissAlert(alert.id);
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKeyMetrics(BuildContext context, PerformanceStatistics stats) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Metrics', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildMetricCard('Total Videos', '${stats.totalVideos}', Icons.video_library),
                _buildMetricCard('Ready Videos', '${stats.readyVideos}', Icons.check_circle),
                _buildMetricCard('Loading', '${stats.loadingVideos}', Icons.downloading),
                _buildMetricCard('Failed', '${stats.failedVideos}', Icons.error),
                _buildMetricCard('Controllers', '${stats.currentControllers}', Icons.smart_display),
                _buildMetricCard('Avg Load Time', '${stats.averagePreloadTime.toStringAsFixed(0)}ms', Icons.speed),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMemoryAnalysis(BuildContext context, MemoryUsageAnalysis analysis) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Memory Usage Analysis', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMemoryMetric('Average', '${analysis.average.toStringAsFixed(0)}MB'),
                ),
                Expanded(
                  child: _buildMemoryMetric('Peak', '${analysis.peak}MB'),
                ),
                Expanded(
                  child: _buildMemoryMetric('Minimum', '${analysis.minimum}MB'),
                ),
                Expanded(
                  child: _buildMemoryTrend(analysis.trend),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (analysis.distribution.isNotEmpty) ...[
              Text('Distribution', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...analysis.distribution.map((bucket) => _buildDistributionBar(
                '${bucket.rangeStart}-${bucket.rangeEnd}MB',
                bucket.percentage,
                bucket.count,
              )),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildMemoryTrend(MemoryTrend trend) {
    final icon = switch (trend.direction) {
      TrendDirection.increasing => Icons.trending_up,
      TrendDirection.decreasing => Icons.trending_down,
      TrendDirection.stable => Icons.trending_flat,
    };
    
    final color = switch (trend.direction) {
      TrendDirection.increasing => Colors.red,
      TrendDirection.decreasing => Colors.green,
      TrendDirection.stable => Colors.grey,
    };
    
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        Text(
          '${(trend.changeRate * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Text(
          'Trend',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildDistributionBar(String label, double percentage, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreloadAnalysis(BuildContext context, PreloadPerformanceAnalysis analysis) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preload Performance', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPreloadMetric(
                    'Success Rate',
                    '${(analysis.successRate * 100).toStringAsFixed(1)}%',
                    analysis.successRate > 0.9 ? Colors.green : Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildPreloadMetric(
                    'Avg Time',
                    '${analysis.averageTime.inMilliseconds}ms',
                    analysis.averageTime.inSeconds < 3 ? Colors.green : Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildPreloadMetric(
                    'Median Time',
                    '${analysis.medianTime.inMilliseconds}ms',
                    analysis.medianTime.inSeconds < 2 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPreloadCount('Fast (<1s)', analysis.fastPreloads, Colors.green),
                ),
                Expanded(
                  child: _buildPreloadCount('Slow (>5s)', analysis.slowPreloads, Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPreloadMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildPreloadCount(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorAnalysis(BuildContext context, ErrorAnalysis analysis) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error Analysis', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildErrorMetric('Total Errors', '${analysis.totalErrors}'),
                ),
                Expanded(
                  child: _buildErrorMetric('Unique Errors', '${analysis.uniqueErrors}'),
                ),
                Expanded(
                  child: _buildErrorMetric('Error Rate', '${(analysis.errorRate * 100).toStringAsFixed(1)}%'),
                ),
              ],
            ),
            if (analysis.topErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Top Errors', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...analysis.topErrors.take(3).map((error) => _buildErrorItem(error)),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.red,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildErrorItem(ErrorSummary error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${error.count}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendations(BuildContext context, List<PerformanceRecommendation> recommendations) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recommendations', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...recommendations.map((rec) => _buildRecommendationItem(rec)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecommendationItem(PerformanceRecommendation recommendation) {
    final color = switch (recommendation.priority) {
      RecommendationPriority.critical => Colors.red,
      RecommendationPriority.high => Colors.orange,
      RecommendationPriority.medium => Colors.blue,
      RecommendationPriority.low => Colors.grey,
    };
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.left(color: color, width: 4),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getRecommendationIcon(recommendation.type),
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  recommendation.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    recommendation.priority.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: color.withOpacity(0.2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.description,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Action: ${recommendation.action}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdvancedMetrics(BuildContext context, PerformanceStatistics stats, PerformanceAnalytics analytics) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Advanced Metrics', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Circuit Breaker Trips:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (stats.circuitBreakerTrips.isEmpty)
              const Text('No circuit breaker trips recorded')
            else
              ...stats.circuitBreakerTrips.entries.map((entry) => 
                Text('${entry.key}: ${entry.value} trips')),
            const SizedBox(height: 16),
            Text('Sample Data:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Total samples: ${stats.sampleCount}'),
            Text('Time range: ${analytics.timeRange.inHours}h'),
            Text('Relevant samples: ${analytics.sampleCount}'),
          ],
        ),
      ),
    );
  }
  
  IconData _getRecommendationIcon(RecommendationType type) {
    return switch (type) {
      RecommendationType.memory => Icons.memory,
      RecommendationType.performance => Icons.speed,
      RecommendationType.network => Icons.network_check,
      RecommendationType.configuration => Icons.settings,
    };
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}