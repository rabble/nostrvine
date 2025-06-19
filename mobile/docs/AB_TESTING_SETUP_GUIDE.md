# A/B Testing Framework Setup Guide

## Overview

This guide explains how to set up and use the A/B testing framework for NostrVine's video system migration. The framework enables controlled rollout from the legacy dual-list architecture to the new TDD-driven video management system.

## Architecture

```
User Request
     │
     ▼
VideoSystemABProvider ──┐
     │                  │
     ├─ A/B Testing ────┤
     │  Decision        │
     ▼                  ▼
New TDD System    Legacy System
(Treatment)       (Control)
     │                  │
     ▼                  ▼
Analytics & Monitoring
```

## Quick Setup

### 1. Initialize A/B Testing Service

```dart
// main.dart
import 'package:provider/provider.dart';
import 'lib/services/ab_testing_service.dart';
import 'lib/providers/video_system_ab_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize A/B testing service
  await ABTestingService.instance.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // A/B Testing Service
        ChangeNotifierProvider.value(
          value: ABTestingService.instance,
        ),
        
        // New Video Manager
        ChangeNotifierProvider(
          create: (_) => VideoManagerService(),
        ),
        
        // A/B Testing Provider for Video System
        ChangeNotifierProxyProvider2<ABTestingService, VideoManagerService, VideoSystemABProvider>(
          create: (context) => VideoSystemABProviderFactory.create(
            abTesting: context.read<ABTestingService>(),
            newVideoManager: context.read<VideoManagerService>(),
            userId: UserService.getCurrentUserId(), // Your user service
          ),
          update: (context, abTesting, videoManager, previous) => 
              previous ?? VideoSystemABProviderFactory.create(
                abTesting: abTesting,
                newVideoManager: videoManager,
                userId: UserService.getCurrentUserId(),
              ),
        ),
      ],
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }
}
```

### 2. Use A/B Testing in Your UI

```dart
// screens/feed_screen.dart
class FeedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<VideoSystemABProvider>(
      builder: (context, videoProvider, child) {
        // Use unified interface regardless of underlying system
        final videos = videoProvider.videos;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Video Feed'),
            subtitle: Text(
              videoProvider.isUsingNewSystem 
                  ? 'New System' 
                  : 'Legacy System'
            ),
          ),
          body: ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoFeedItem(
                video: video,
                controller: videoProvider.getController(video.id),
                onTap: () => _onVideoTapped(context, video, videoProvider),
              );
            },
          ),
        );
      },
    );
  }
  
  void _onVideoTapped(BuildContext context, VideoEvent video, VideoSystemABProvider provider) {
    // Track user engagement
    provider.trackUserEngagement({
      'action': 'video_tapped',
      'video_id': video.id,
      'position': 'feed',
    });
    
    // Navigate to video detail
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoDetailScreen(videoId: video.id),
      ),
    );
  }
}
```

### 3. Configure Rollout Percentages

```dart
// Configure rollout via remote config or locally
class RolloutConfig {
  static void updateVideoSystemRollout(int percentage) {
    // Update remote config
    ABTestingService.instance.updateRemoteConfig(
      'video_system_rollout_percentage', 
      percentage
    );
    
    // Log rollout change
    Analytics.track('rollout_percentage_changed', {
      'experiment': 'video_system_migration_v2',
      'old_percentage': _getPreviousPercentage(),
      'new_percentage': percentage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

## Detailed Configuration

### Experiment Setup

#### 1. Define Custom Experiments

```dart
// Register additional experiments
class ExperimentSetup {
  static void registerAllExperiments() {
    final abTesting = ABTestingService.instance;
    
    // Video System Migration (primary experiment)
    abTesting.registerExperiment(ExperimentConfig(
      id: 'video_system_migration_v2',
      name: 'TDD Video System Migration',
      description: 'Gradual migration from legacy to TDD video architecture',
      treatmentPercentage: 0, // Start with 0%
      enabled: true,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 60)),
      metadata: {
        'primary_metric': 'video_load_success_rate',
        'secondary_metrics': ['memory_usage', 'crash_rate', 'user_engagement'],
        'minimum_sample_size': 1000,
      },
    ));
    
    // Performance Monitoring Experiment
    abTesting.registerExperiment(ExperimentConfig(
      id: 'performance_monitoring_v1',
      name: 'Performance Monitoring Dashboard',
      description: 'Enable real-time performance monitoring',
      treatmentPercentage: 50,
      enabled: true,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 30)),
      metadata: {
        'primary_metric': 'developer_productivity',
        'secondary_metrics': ['bug_detection_rate', 'response_time'],
      },
    ));
    
    // New UI Components Experiment
    abTesting.registerExperiment(ExperimentConfig(
      id: 'video_ui_refresh_v1',
      name: 'Video UI Component Refresh',
      description: 'Test new video player controls and animations',
      treatmentPercentage: 25,
      enabled: true,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 45)),
      metadata: {
        'primary_metric': 'user_engagement_time',
        'secondary_metrics': ['video_completion_rate', 'user_satisfaction'],
      },
    ));
  }
}
```

#### 2. Custom Event Tracking

```dart
// Track specific video system events
class VideoSystemTracking {
  static void trackVideoLoadPerformance(String videoId, Duration loadTime, bool success) {
    ABTestingService.instance.trackEvent(
      'video_system_migration_v2',
      'video_load_performance',
      properties: {
        'video_id': videoId,
        'load_time_ms': loadTime.inMilliseconds,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  static void trackMemoryUsage(int memoryMB, int controllerCount) {
    ABTestingService.instance.trackEvent(
      'video_system_migration_v2',
      'memory_usage',
      properties: {
        'memory_mb': memoryMB,
        'controller_count': controllerCount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  static void trackUserEngagement(String action, Map<String, dynamic> context) {
    ABTestingService.instance.trackEvent(
      'video_system_migration_v2',
      'user_engagement',
      properties: {
        'action': action,
        'context': context,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
```

### Integration Patterns

#### 1. Feature Flagging

```dart
// Use A/B testing for feature flags
class FeatureFlags {
  static bool isNewVideoSystemEnabled() {
    return ABTestingService.instance.isUserInTreatment('video_system_migration_v2');
  }
  
  static bool isPerformanceMonitoringEnabled() {
    return ABTestingService.instance.isUserInTreatment('performance_monitoring_v1');
  }
  
  static bool isNewUIEnabled() {
    return ABTestingService.instance.isUserInTreatment('video_ui_refresh_v1');
  }
}
```

#### 2. Conditional UI Components

```dart
// Conditionally render UI based on experiments
class ConditionalVideoPlayer extends StatelessWidget {
  final VideoEvent video;
  
  const ConditionalVideoPlayer({required this.video});
  
  @override
  Widget build(BuildContext context) {
    final useNewUI = ABTestingService.instance.isUserInTreatment('video_ui_refresh_v1');
    
    if (useNewUI) {
      return NewVideoPlayerWidget(video: video);
    } else {
      return LegacyVideoPlayerWidget(video: video);
    }
  }
}
```

#### 3. Performance Comparison

```dart
// Compare performance between systems
class PerformanceComparison {
  static Future<void> benchmarkVideoLoad() async {
    final abTesting = ABTestingService.instance;
    final useNewSystem = abTesting.isUserInTreatment('video_system_migration_v2');
    
    final startTime = DateTime.now();
    bool success = false;
    
    try {
      if (useNewSystem) {
        await _loadVideoWithNewSystem();
      } else {
        await _loadVideoWithLegacySystem();
      }
      success = true;
    } catch (e) {
      success = false;
    }
    
    final duration = DateTime.now().difference(startTime);
    
    // Track performance metrics
    abTesting.trackEvent(
      'video_system_migration_v2',
      'video_load_benchmark',
      properties: {
        'system': useNewSystem ? 'new' : 'legacy',
        'duration_ms': duration.inMilliseconds,
        'success': success,
      },
    );
  }
}
```

## Rollout Strategy

### Phase 1: Testing (Week 1)
```dart
// 0% rollout - internal testing only
RolloutConfig.updateVideoSystemRollout(0);

// Force treatment for specific test users
class TestUserOverrides {
  static bool shouldForceTreatment(String userId) {
    final testUsers = [
      'internal-dev-1',
      'internal-dev-2', 
      'qa-tester-1',
      'beta-user-group',
    ];
    
    return testUsers.contains(userId) || userId.startsWith('test-');
  }
}
```

### Phase 2: Canary Release (Week 2)
```dart
// 5% rollout to canary users
RolloutConfig.updateVideoSystemRollout(5);

// Enhanced monitoring for canary phase
class CanaryMonitoring {
  static void startCanaryMonitoring() {
    Timer.periodic(Duration(minutes: 5), (_) {
      final results = ABTestingService.instance.getExperimentResults('video_system_migration_v2');
      
      // Auto-halt if metrics degrade
      if (results.treatmentConversionRate < results.controlConversionRate * 0.9) {
        _haltRollout('Conversion rate degraded');
      }
      
      if (_getCrashRate() > _getBaselineCrashRate() * 1.5) {
        _haltRollout('Crash rate increased');
      }
    });
  }
  
  static void _haltRollout(String reason) {
    RolloutConfig.updateVideoSystemRollout(0);
    _alertOpsTeam('Rollout halted: $reason');
  }
}
```

### Phase 3: Gradual Rollout (Weeks 3-5)
```dart
// Gradual increase: 10% → 25% → 50% → 100%
class GradualRollout {
  static final rolloutSchedule = [
    RolloutStep(percentage: 10, duration: Duration(days: 3)),
    RolloutStep(percentage: 25, duration: Duration(days: 4)),
    RolloutStep(percentage: 50, duration: Duration(days: 5)),
    RolloutStep(percentage: 100, duration: Duration(days: 7)),
  ];
  
  static void executeRollout() async {
    for (final step in rolloutSchedule) {
      // Update rollout percentage
      RolloutConfig.updateVideoSystemRollout(step.percentage);
      
      // Monitor for step duration
      await Future.delayed(step.duration);
      
      // Check health before proceeding
      if (!_isSystemHealthy()) {
        _pauseRollout();
        break;
      }
    }
  }
}
```

## Analytics and Monitoring

### Real-time Dashboard

```dart
// A/B testing analytics dashboard
class ABTestingDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ABTestingService>(
      builder: (context, abTesting, child) {
        final results = abTesting.getExperimentResults('video_system_migration_v2');
        
        return Scaffold(
          appBar: AppBar(title: Text('A/B Testing Dashboard')),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Experiment Overview
                _buildExperimentOverview(results),
                
                // Performance Metrics
                _buildPerformanceMetrics(results),
                
                // Statistical Significance
                _buildStatisticalAnalysis(results),
                
                // Rollout Controls
                _buildRolloutControls(),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildExperimentOverview(ExperimentResults results) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video System Migration Experiment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Control Users', '${results.controlUsers}')),
                Expanded(child: _buildMetricCard('Treatment Users', '${results.treatmentUsers}')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Control Conversion', '${(results.controlConversionRate * 100).toStringAsFixed(1)}%')),
                Expanded(child: _buildMetricCard('Treatment Conversion', '${(results.treatmentConversionRate * 100).toStringAsFixed(1)}%')),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatisticalAnalysis(ExperimentResults results) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistical Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Lift', '${results.liftPercentage.toStringAsFixed(1)}%')),
                Expanded(child: _buildMetricCard('P-Value', '${results.pValue.toStringAsFixed(3)}')),
                Expanded(child: _buildMetricCard('Significant', results.isSignificant ? 'Yes' : 'No')),
                Expanded(child: _buildMetricCard('Confidence', '${results.confidence.toStringAsFixed(1)}%')),
              ],
            ),
            if (results.isSignificant)
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Results are statistically significant! Treatment shows ${results.liftPercentage > 0 ? "improvement" : "degradation"} over control.',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Performance Tracking

```dart
// Track A/B testing performance impact
class ABTestingPerformanceTracker {
  static final Map<String, List<Duration>> _operationTimes = {};
  
  static void trackOperation(String operation, Duration duration, String variant) {
    final key = '${operation}_$variant';
    _operationTimes.putIfAbsent(key, () => []).add(duration);
    
    // Keep only recent measurements
    if (_operationTimes[key]!.length > 100) {
      _operationTimes[key]!.removeRange(0, 50);
    }
  }
  
  static Map<String, double> getAverageOperationTimes() {
    final averages = <String, double>{};
    
    for (final entry in _operationTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final avgMs = times.fold(0, (sum, duration) => sum + duration.inMilliseconds) / times.length;
        averages[entry.key] = avgMs;
      }
    }
    
    return averages;
  }
}
```

## Testing the A/B Framework

### Unit Tests

```dart
// test/services/ab_testing_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/ab_testing_service.dart';

void main() {
  group('ABTestingService Tests', () {
    late ABTestingService abTesting;
    
    setUp(() async {
      abTesting = ABTestingService.instance;
      await abTesting.initialize();
    });
    
    test('should assign users to treatment consistently', () {
      final userId = 'test-user-123';
      
      final assignment1 = abTesting.isUserInTreatment('video_system_migration_v2', userId: userId);
      final assignment2 = abTesting.isUserInTreatment('video_system_migration_v2', userId: userId);
      
      expect(assignment1, equals(assignment2));
    });
    
    test('should track events correctly', () {
      abTesting.trackEvent('video_system_migration_v2', 'test_event', 
          userId: 'test-user', properties: {'key': 'value'});
      
      // Verify event was tracked (implementation dependent)
    });
    
    test('should calculate statistical significance', () {
      // Set up experiment with known data
      // ... test statistical calculations
    });
  });
}
```

### Integration Tests

```dart
// test/integration/ab_testing_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/providers/video_system_ab_provider.dart';

void main() {
  group('A/B Testing Integration', () {
    testWidgets('should use correct video system based on assignment', (tester) async {
      final abProvider = VideoSystemABProviderFactory.createForTesting(
        newVideoManager: MockVideoManager(),
      );
      
      // Test that treatment group uses new system
      expect(abProvider.isUsingNewSystem, isTrue);
      
      // Test operations delegate correctly
      final videos = abProvider.videos;
      expect(videos, isA<List<VideoEvent>>());
    });
  });
}
```

## Production Considerations

### Remote Configuration

```dart
// Use Firebase Remote Config or similar
class RemoteABConfig {
  static Future<void> syncRemoteConfig() async {
    await FirebaseRemoteConfig.instance.fetchAndActivate();
    
    final rolloutPercentage = FirebaseRemoteConfig.instance.getInt('video_system_rollout');
    final experimentEnabled = FirebaseRemoteConfig.instance.getBool('video_system_experiment_enabled');
    
    ABTestingService.instance.updateRemoteConfig('video_system_rollout_percentage', rolloutPercentage);
    ABTestingService.instance.updateRemoteConfig('video_system_experiment_enabled', experimentEnabled);
  }
}
```

### Data Export

```dart
// Export experiment data for analysis
class ExperimentDataExporter {
  static Future<void> exportToAnalytics() async {
    final abTesting = ABTestingService.instance;
    
    for (final experiment in abTesting.getActiveExperiments()) {
      final data = abTesting.exportExperimentData(experiment.id);
      
      // Send to your analytics platform
      await AnalyticsService.sendExperimentData(data);
    }
  }
}
```

### Privacy and Compliance

```dart
// Ensure user privacy compliance
class PrivacyCompliantABTesting {
  static bool canTrackUser(String userId) {
    // Check user consent and privacy settings
    return UserPreferences.hasAnalyticsConsent(userId) &&
           !UserPreferences.isOptedOutOfExperiments(userId);
  }
  
  static void anonymizeUserData(String userId) {
    // Hash or anonymize user identifiers
    final hashedUserId = _hashUserId(userId);
    ABTestingService.instance.trackEvent(
      'video_system_migration_v2',
      'user_anonymized',
      userId: hashedUserId,
    );
  }
}
```

## Conclusion

The A/B testing framework provides a safe, data-driven approach to migrating NostrVine's video system. It enables:

- **Controlled Rollout**: Gradual exposure to minimize risk
- **Performance Monitoring**: Real-time tracking of key metrics
- **Statistical Analysis**: Rigorous evaluation of experiment results
- **Easy Rollback**: Quick reversion if issues arise
- **User Segmentation**: Targeted rollout to specific user groups

Use this framework to confidently deploy the new TDD video system while maintaining high availability and user experience.