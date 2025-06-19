# Performance Monitoring Setup Guide

## Overview

This guide explains how to integrate and configure the video performance monitoring system for NostrVine. The monitoring system provides real-time analytics, alerting, and comprehensive performance insights for the TDD video management system.

## Architecture

The performance monitoring system consists of three main components:

1. **VideoPerformanceMonitor**: Core monitoring service
2. **VideoPerformanceDashboard**: UI widget for visualization
3. **Analytics Integration**: External analytics platform integration

## Quick Setup

### 1. Add Performance Monitor to Your App

```dart
// main.dart
import 'package:provider/provider.dart';
import 'lib/services/video_performance_monitor.dart';
import 'lib/services/video_manager_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Video Manager
        ChangeNotifierProvider(
          create: (_) => VideoManagerService(),
        ),
        
        // Performance Monitor
        ChangeNotifierProxyProvider<VideoManagerService, VideoPerformanceMonitor>(
          create: (context) => VideoPerformanceMonitor(
            videoManager: context.read<VideoManagerService>(),
            samplingInterval: const Duration(seconds: 30),
            thresholds: const AlertThresholds(
              highMemoryThreshold: 500,    // 500MB warning
              criticalMemoryThreshold: 800, // 800MB critical
              maxControllers: 15,           // Max controllers
              slowPreloadThreshold: Duration(seconds: 5),
            ),
          ),
          update: (context, videoManager, monitor) => monitor ?? VideoPerformanceMonitor(
            videoManager: videoManager,
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

### 2. Start Monitoring

```dart
// In your app's initialization
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Start performance monitoring when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final monitor = context.read<VideoPerformanceMonitor>();
      monitor.startMonitoring();
      
      // Listen for alerts
      monitor.alerts.listen((alert) {
        _handlePerformanceAlert(alert);
      });
    });
  }
  
  void _handlePerformanceAlert(PerformanceAlert alert) {
    // Handle alerts (show notifications, log to analytics, etc.)
    if (alert.severity == AlertSeverity.critical) {
      _showCriticalAlert(alert);
    }
    
    // Log to analytics
    Analytics.track('performance_alert', {
      'type': alert.type.name,
      'severity': alert.severity.name,
      'message': alert.message,
    });
  }
}
```

### 3. Add Dashboard to Your App

```dart
// Add performance dashboard as a debug/admin screen
import 'lib/widgets/video_performance_dashboard.dart';

class DebugScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debug')),
      body: Column(
        children: [
          ListTile(
            title: Text('Performance Dashboard'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPerformanceDashboard(
                  showAdvancedMetrics: true,
                ),
              ),
            ),
          ),
          // Other debug options...
        ],
      ),
    );
  }
}
```

## Detailed Configuration

### Alert Thresholds

Customize alert thresholds based on your requirements:

```dart
const alertThresholds = AlertThresholds(
  // Memory thresholds
  highMemoryThreshold: 500,      // MB - Warning level
  criticalMemoryThreshold: 800,  // MB - Critical level
  
  // Controller limits
  maxControllers: 15,            // Maximum concurrent controllers
  
  // Performance thresholds
  slowPreloadThreshold: Duration(seconds: 5),     // Slow preload warning
  preloadFailureRateThreshold: 0.1,               // 10% failure rate alert
  highFailureRateThreshold: 0.2,                  // 20% overall failure rate
);
```

### Sampling Configuration

Configure monitoring frequency and data retention:

```dart
final monitor = VideoPerformanceMonitor(
  videoManager: videoManager,
  samplingInterval: const Duration(seconds: 30), // Sample every 30s
  maxSampleHistory: 1000,                        // Keep 1000 samples (~8 hours)
  thresholds: alertThresholds,
);
```

### Dashboard Customization

Customize the dashboard for different user roles:

```dart
// Basic dashboard for users
VideoPerformanceDashboard(
  showAdvancedMetrics: false,
  refreshInterval: Duration(seconds: 10),
)

// Advanced dashboard for developers/admins
VideoPerformanceDashboard(
  showAdvancedMetrics: true,
  refreshInterval: Duration(seconds: 5),
)
```

## Integration Patterns

### Recording Custom Events

Record performance events from your video manager:

```dart
class VideoManagerService extends ChangeNotifier implements IVideoManager {
  VideoPerformanceMonitor? _performanceMonitor;
  
  void setPerformanceMonitor(VideoPerformanceMonitor monitor) {
    _performanceMonitor = monitor;
  }
  
  @override
  Future<void> preloadVideo(String videoId) async {
    final startTime = DateTime.now();
    bool success = false;
    String? errorMessage;
    
    try {
      // ... preload logic ...
      success = true;
    } catch (e) {
      success = false;
      errorMessage = e.toString();
    } finally {
      final duration = DateTime.now().difference(startTime);
      
      // Record preload event
      _performanceMonitor?.recordPreloadEvent(
        videoId: videoId,
        success: success,
        duration: duration,
        errorMessage: errorMessage,
      );
    }
  }
  
  @override
  Future<void> handleMemoryPressure() async {
    final beforeMemory = getDebugInfo()['estimatedMemoryMB'] as int;
    final beforeControllers = _controllers.length;
    
    // ... memory cleanup logic ...
    
    final afterControllers = _controllers.length;
    final controllersDisposed = beforeControllers - afterControllers;
    
    // Record memory pressure event
    _performanceMonitor?.recordMemoryPressure(
      beforeMemory,
      controllersDisposed,
    );
  }
}
```

### Circuit Breaker Integration

Record circuit breaker events:

```dart
class CircuitBreakerService {
  final VideoPerformanceMonitor? _performanceMonitor;
  
  void _tripCircuitBreaker(String videoId, String reason) {
    // ... circuit breaker logic ...
    
    // Record the trip
    _performanceMonitor?.recordCircuitBreakerTrip(videoId, reason);
  }
}
```

## Analytics Integration

### Firebase Analytics

```dart
class PerformanceAnalyticsService {
  static void trackPerformanceMetrics(PerformanceStatistics stats) {
    FirebaseAnalytics.instance.logEvent(
      name: 'video_performance_sample',
      parameters: {
        'memory_mb': stats.currentMemoryMB,
        'controllers': stats.currentControllers,
        'total_videos': stats.totalVideos,
        'ready_videos': stats.readyVideos,
        'success_rate': (stats.preloadSuccessRate * 100).round(),
        'avg_preload_time': stats.averagePreloadTime.round(),
      },
    );
  }
  
  static void trackAlert(PerformanceAlert alert) {
    FirebaseAnalytics.instance.logEvent(
      name: 'performance_alert',
      parameters: {
        'alert_type': alert.type.name,
        'severity': alert.severity.name,
        'message': alert.message,
      },
    );
  }
}
```

### Custom Analytics

```dart
class CustomAnalyticsService {
  static final HttpClient _client = HttpClient();
  
  static Future<void> sendMetrics(PerformanceStatistics stats) async {
    final request = await _client.postUrl(Uri.parse('YOUR_ANALYTICS_ENDPOINT'));
    request.headers.contentType = ContentType.json;
    
    final data = {
      'timestamp': stats.timestamp.toIso8601String(),
      'memory_mb': stats.currentMemoryMB,
      'controllers': stats.currentControllers,
      'videos': {
        'total': stats.totalVideos,
        'ready': stats.readyVideos,
        'loading': stats.loadingVideos,
        'failed': stats.failedVideos,
      },
      'performance': {
        'avg_preload_time': stats.averagePreloadTime,
        'success_rate': stats.preloadSuccessRate,
      },
      'trends': {
        'memory': stats.memoryTrend.direction.name,
        'performance': stats.performanceTrend.direction.name,
      },
    };
    
    request.write(jsonEncode(data));
    await request.close();
  }
}
```

## Production Deployment

### Monitoring Schedule

Set up monitoring to run at appropriate intervals:

```dart
// Development: Frequent monitoring
final devMonitor = VideoPerformanceMonitor(
  videoManager: videoManager,
  samplingInterval: Duration(seconds: 10),
  maxSampleHistory: 500,
);

// Production: Balanced monitoring
final prodMonitor = VideoPerformanceMonitor(
  videoManager: videoManager,
  samplingInterval: Duration(seconds: 30),
  maxSampleHistory: 1000,
);

// Performance testing: Intensive monitoring
final testMonitor = VideoPerformanceMonitor(
  videoManager: videoManager,
  samplingInterval: Duration(seconds: 5),
  maxSampleHistory: 2000,
);
```

### Alert Handling

Set up proper alert handling for production:

```dart
class ProductionAlertHandler {
  static void handleAlert(PerformanceAlert alert) {
    switch (alert.severity) {
      case AlertSeverity.critical:
        // Send to on-call team
        _sendPagerDutyAlert(alert);
        // Log to error tracking
        Sentry.captureMessage(
          'Critical video performance alert: ${alert.message}',
          level: SentryLevel.error,
        );
        break;
        
      case AlertSeverity.warning:
        // Log to monitoring system
        _sendToDatadog(alert);
        break;
        
      case AlertSeverity.info:
        // Just log locally
        debugPrint('Info alert: ${alert.message}');
        break;
    }
  }
  
  static void _sendPagerDutyAlert(PerformanceAlert alert) {
    // Integration with PagerDuty
    PagerDuty.createIncident(
      title: 'Video Performance Critical Alert',
      description: alert.message,
      severity: 'critical',
      metadata: alert.metadata,
    );
  }
  
  static void _sendToDatadog(PerformanceAlert alert) {
    // Integration with Datadog
    Datadog.sendEvent(
      title: 'Video Performance Warning',
      text: alert.message,
      tags: ['video_performance', 'alert', alert.type.name],
      alertType: 'warning',
    );
  }
}
```

### Memory Management

Configure monitoring to help with memory management:

```dart
class MemoryAwareMonitoring {
  static void setupMemoryPressureHandling(VideoPerformanceMonitor monitor) {
    monitor.alerts.listen((alert) {
      if (alert.type == AlertType.highMemoryUsage) {
        // Trigger aggressive cleanup
        final videoManager = GetIt.instance<IVideoManager>();
        videoManager.handleMemoryPressure();
        
        // Reduce monitoring frequency temporarily
        monitor.stopMonitoring();
        Timer(Duration(minutes: 2), () {
          monitor.startMonitoring();
        });
      }
    });
  }
}
```

## Testing the Monitoring System

### Unit Tests

```dart
// test/services/video_performance_monitor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_performance_monitor.dart';
import '../mocks/mock_video_manager.dart';

void main() {
  group('VideoPerformanceMonitor Tests', () {
    late VideoPerformanceMonitor monitor;
    late MockVideoManager mockVideoManager;
    
    setUp(() {
      mockVideoManager = MockVideoManager();
      monitor = VideoPerformanceMonitor(
        videoManager: mockVideoManager,
        samplingInterval: Duration(milliseconds: 100),
        thresholds: AlertThresholds(
          highMemoryThreshold: 100, // Low threshold for testing
        ),
      );
    });
    
    tearDown(() {
      monitor.dispose();
      mockVideoManager.dispose();
    });
    
    test('should start and stop monitoring', () {
      expect(monitor.isMonitoring, isFalse);
      
      monitor.startMonitoring();
      expect(monitor.isMonitoring, isTrue);
      
      monitor.stopMonitoring();
      expect(monitor.isMonitoring, isFalse);
    });
    
    test('should trigger high memory alert', () async {
      final alerts = <PerformanceAlert>[];
      monitor.alerts.listen(alerts.add);
      
      // Mock high memory usage
      mockVideoManager.setHighMemoryUsage(600);
      monitor.startMonitoring();
      
      await Future.delayed(Duration(milliseconds: 200));
      
      expect(alerts, isNotEmpty);
      expect(alerts.first.type, AlertType.highMemoryUsage);
    });
    
    test('should record preload events', () {
      monitor.recordPreloadEvent(
        videoId: 'test-video',
        success: true,
        duration: Duration(milliseconds: 1500),
      );
      
      final stats = monitor.getStatistics();
      expect(stats.averagePreloadTime, 1500.0);
      expect(stats.preloadSuccessRate, 1.0);
    });
  });
}
```

### Integration Tests

```dart
// test/integration/performance_monitoring_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/services/video_performance_monitor.dart';

void main() {
  group('Performance Monitoring Integration', () {
    testWidgets('should monitor video manager in real app', (tester) async {
      final videoManager = VideoManagerService();
      final monitor = VideoPerformanceMonitor(
        videoManager: videoManager,
        samplingInterval: Duration(milliseconds: 100),
      );
      
      monitor.startMonitoring();
      
      // Add some videos
      for (int i = 0; i < 10; i++) {
        await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
          id: 'video-$i',
        ));
      }
      
      // Wait for monitoring samples
      await tester.pump(Duration(milliseconds: 200));
      
      final stats = monitor.getStatistics();
      expect(stats.totalVideos, 10);
      expect(stats.sampleCount, greaterThan(0));
      
      monitor.dispose();
      videoManager.dispose();
    });
  });
}
```

## Troubleshooting

### Common Issues

#### High Memory Usage Alerts
```dart
// Check if memory thresholds are appropriate
final stats = monitor.getStatistics();
print('Current memory: ${stats.currentMemoryMB}MB');
print('Controllers: ${stats.currentControllers}');

// Adjust thresholds if needed
final newThresholds = AlertThresholds(
  highMemoryThreshold: 600,  // Increase if too sensitive
  criticalMemoryThreshold: 900,
);
```

#### Missing Performance Data
```dart
// Ensure monitoring is started
if (!monitor.isMonitoring) {
  monitor.startMonitoring();
}

// Check sampling interval
print('Sampling interval: ${monitor.samplingInterval}');
print('Sample count: ${monitor.getStatistics().sampleCount}');
```

#### Alert Spam
```dart
// Implement alert throttling
class ThrottledAlertHandler {
  static final Map<AlertType, DateTime> _lastAlerts = {};
  static const Duration throttleDuration = Duration(minutes: 5);
  
  static bool shouldShowAlert(PerformanceAlert alert) {
    final lastAlert = _lastAlerts[alert.type];
    if (lastAlert == null) {
      _lastAlerts[alert.type] = DateTime.now();
      return true;
    }
    
    final timeSinceLastAlert = DateTime.now().difference(lastAlert);
    if (timeSinceLastAlert > throttleDuration) {
      _lastAlerts[alert.type] = DateTime.now();
      return true;
    }
    
    return false;
  }
}
```

## Best Practices

1. **Start Simple**: Begin with basic monitoring and gradually add more metrics
2. **Tune Thresholds**: Adjust alert thresholds based on real usage patterns
3. **Monitor Responsibly**: Don't over-monitor in production to avoid performance impact
4. **Act on Alerts**: Ensure alerts lead to actionable responses
5. **Regular Review**: Periodically review and optimize monitoring configuration

## Conclusion

The performance monitoring system provides comprehensive insights into video system behavior, enabling proactive optimization and reliable production deployments. Start with the basic setup and gradually enhance based on your specific needs and usage patterns.