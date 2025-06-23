# Operational Runbooks for OpenVine Video System

## Overview

This document provides operational procedures and troubleshooting guides for maintaining the OpenVine video system in production. It covers incident response, performance monitoring, and maintenance procedures.

## Table of Contents

1. [Emergency Response Procedures](#emergency-response-procedures)
2. [Performance Monitoring](#performance-monitoring)
3. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)
4. [Maintenance Procedures](#maintenance-procedures)
5. [Deployment Procedures](#deployment-procedures)
6. [Alerting and Escalation](#alerting-and-escalation)

## Emergency Response Procedures

### High Memory Usage Alert

**Severity**: Critical  
**SLA**: Respond within 15 minutes

#### Symptoms
- Memory usage >800MB sustained for >5 minutes
- Users reporting app crashes
- Performance monitoring alerts firing

#### Immediate Actions
1. **Check Current System Status**
   ```bash
   # Via analytics dashboard or debug endpoint
   curl -X GET https://api.openvine.co/debug/video-system-status
   ```

2. **Trigger Emergency Memory Cleanup**
   ```dart
   // Emergency memory pressure handler
   await videoManager.handleMemoryPressure();
   
   // Check results
   final debugInfo = videoManager.getDebugInfo();
   print('Post-cleanup memory: ${debugInfo['estimatedMemoryMB']}MB');
   ```

3. **Enable Circuit Breaker Mode**
   ```dart
   // Temporarily disable video preloading
   FeatureFlags.setFlag('emergency_mode', true);
   
   // Reduce preload configuration
   final emergencyConfig = VideoManagerConfig(
     maxVideos: 25,
     preloadAhead: 1,
     preloadBehind: 0,
   );
   ```

4. **Monitor Recovery**
   - Watch memory usage for next 10 minutes
   - Verify user crash rates return to normal
   - Check video load success rates

#### Root Cause Investigation
1. **Analyze Memory Growth Pattern**
   ```dart
   // Export memory usage data
   final analytics = performanceMonitor.getAnalytics(
     timeRange: Duration(hours: 2)
   );
   
   print('Memory trend: ${analytics.memoryUsage.trend.direction}');
   print('Growth rate: ${analytics.memoryUsage.growthRateMBPerSecond}MB/s');
   ```

2. **Check for Memory Leaks**
   - Review controller disposal logs
   - Analyze video state transitions
   - Check for stuck preload operations

3. **User Pattern Analysis**
   - Heavy scrolling patterns
   - Specific content types causing issues
   - Geographic distribution of affected users

#### Recovery Actions
1. **Gradual System Recovery**
   ```dart
   // Gradually restore normal operation
   await Future.delayed(Duration(minutes: 5));
   FeatureFlags.setFlag('emergency_mode', false);
   
   // Restore normal configuration
   final normalConfig = VideoManagerConfig.wifi();
   ```

2. **Post-Incident Monitoring**
   - Monitor for 2 hours after recovery
   - Document timeline and actions taken
   - Schedule follow-up investigation

### High Crash Rate Alert

**Severity**: Critical  
**SLA**: Respond within 10 minutes

#### Symptoms
- Crash rate >5% above baseline
- Multiple "VideoPlayerController was disposed" errors
- User reports of app instability

#### Immediate Actions
1. **Emergency Rollback**
   ```dart
   // Immediately disable new video system
   FeatureFlags.setFlag('new_video_manager', false);
   ABTestingService.instance.updateRemoteConfig('video_system_rollout_percentage', 0);
   ```

2. **Analyze Crash Reports**
   ```bash
   # Filter recent crashes related to video system
   grep -E "(VideoPlayerController|VideoManager|preload)" crash_logs.txt | tail -100
   ```

3. **Check for Race Conditions**
   - Review disposal timing logs
   - Check for concurrent state modifications
   - Analyze preload/dispose race conditions

#### Recovery Actions
1. **Staged Re-enable**
   - Start with 1% rollout after crash investigation
   - Monitor for 1 hour before increasing
   - Implement additional safeguards

2. **Enhanced Monitoring**
   ```dart
   // Enable verbose logging temporarily
   VideoManagerService.debugMode = true;
   
   // Increase monitoring frequency
   performanceMonitor.setSamplingInterval(Duration(seconds: 10));
   ```

### Video Load Failure Spike

**Severity**: High  
**SLA**: Respond within 30 minutes

#### Symptoms
- Video load success rate <85%
- Users unable to play videos
- Timeout errors increasing

#### Immediate Actions
1. **Check Network Conditions**
   ```bash
   # Test video URLs accessibility
   curl -I https://example-video-cdn.com/test-video.mp4
   
   # Check CDN status
   curl -X GET https://status.cdn-provider.com/api/status
   ```

2. **Analyze Failure Patterns**
   ```dart
   final errorAnalysis = performanceMonitor.getAnalytics().errorAnalysis;
   print('Top errors: ${errorAnalysis.topErrors}');
   print('Error rate: ${errorAnalysis.errorRate}');
   ```

3. **Implement Fallback Strategy**
   ```dart
   // Increase retry attempts temporarily
   final recoveryConfig = VideoManagerConfig(
     maxRetries: 5,
     preloadTimeout: Duration(seconds: 15),
   );
   ```

#### Root Cause Analysis
1. **CDN Health Check**
   - Verify CDN performance across regions
   - Check for DNS resolution issues
   - Analyze cache hit rates

2. **Network Quality Analysis**
   - Check cellular vs WiFi performance
   - Analyze geographic distribution of failures
   - Review timeout patterns

3. **URL Validation**
   - Check for malformed video URLs
   - Verify HTTPS certificate issues
   - Test video format compatibility

## Performance Monitoring

### Key Metrics Dashboard

#### Real-time Monitoring
```dart
// Essential metrics to monitor continuously
class ProductionMetrics {
  static void trackKeyMetrics() {
    Timer.periodic(Duration(minutes: 1), (_) {
      final debugInfo = videoManager.getDebugInfo();
      
      // Memory usage
      Analytics.gauge('video_memory_mb', debugInfo['estimatedMemoryMB']);
      
      // Controller count
      Analytics.gauge('video_controllers', debugInfo['activeControllers']);
      
      // Success rates
      final successRate = debugInfo['metrics']['preloadSuccessRate'];
      Analytics.gauge('preload_success_rate', double.parse(successRate.replaceAll('%', '')));
      
      // Performance indicators
      Analytics.gauge('total_videos', debugInfo['totalVideos']);
      Analytics.gauge('ready_videos', debugInfo['readyVideos']);
    });
  }
}
```

#### Alert Thresholds
```yaml
# Production alert configuration
alerts:
  memory_usage:
    warning: 500  # MB
    critical: 800  # MB
    
  controller_count:
    warning: 12
    critical: 16
    
  preload_success_rate:
    warning: 85   # %
    critical: 70  # %
    
  crash_rate:
    warning: 2    # %
    critical: 5   # %
```

### Performance Analysis Tools

#### Memory Usage Analysis
```dart
class MemoryAnalyzer {
  static Map<String, dynamic> analyzeMemoryPattern() {
    final analytics = performanceMonitor.getAnalytics(
      timeRange: Duration(hours: 24)
    );
    
    return {
      'peak_memory': analytics.memoryUsage.peak,
      'average_memory': analytics.memoryUsage.average,
      'growth_trend': analytics.memoryUsage.trend.direction.name,
      'growth_rate': analytics.memoryUsage.growthRateMBPerSecond,
      'distribution': analytics.memoryUsage.distribution,
      'recommendations': _generateMemoryRecommendations(analytics),
    };
  }
}
```

#### Performance Benchmarking
```dart
class ProductionBenchmark {
  static Future<void> runDailyBenchmark() async {
    // Test video addition performance
    final addBenchmark = await _benchmarkVideoAddition();
    
    // Test preload performance
    final preloadBenchmark = await _benchmarkPreloading();
    
    // Test memory cleanup effectiveness
    final cleanupBenchmark = await _benchmarkMemoryCleanup();
    
    // Store results for trending analysis
    Analytics.track('daily_benchmark', {
      'video_addition_ms': addBenchmark.averageTimeMs,
      'preload_success_rate': preloadBenchmark.successRate,
      'cleanup_effectiveness': cleanupBenchmark.memoryReductionPercent,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

## Common Issues and Troubleshooting

### Issue: Videos Not Loading

#### Diagnosis Steps
1. **Check Video URLs**
   ```dart
   // Validate video URL accessibility
   Future<bool> validateVideoUrl(String url) async {
     try {
       final response = await http.head(Uri.parse(url));
       return response.statusCode == 200;
     } catch (e) {
       return false;
     }
   }
   ```

2. **Network Diagnostics**
   ```dart
   // Check network connectivity
   final connectivity = await Connectivity().checkConnectivity();
   print('Network type: $connectivity');
   
   // Test network speed
   final speedTest = await NetworkSpeedTest().testDownloadSpeed();
   print('Download speed: ${speedTest.mbps} Mbps');
   ```

3. **State Analysis**
   ```dart
   // Check video states
   final failedVideos = videoManager.videos
       .where((v) => videoManager.getVideoState(v.id)?.hasFailed == true)
       .toList();
   
   print('Failed videos: ${failedVideos.length}');
   for (final video in failedVideos) {
     final state = videoManager.getVideoState(video.id);
     print('${video.id}: ${state?.error}');
   }
   ```

#### Solutions
1. **URL Validation and Cleanup**
   ```dart
   // Clean up invalid URLs
   for (final video in failedVideos) {
     if (!await validateVideoUrl(video.videoUrl)) {
       // Remove or replace invalid video
       videoManager.disposeVideo(video.id);
     }
   }
   ```

2. **Network-Aware Configuration**
   ```dart
   // Adjust configuration based on network
   final networkConfig = connectivity == ConnectivityResult.mobile
       ? VideoManagerConfig.cellular()
       : VideoManagerConfig.wifi();
   ```

### Issue: High Memory Usage

#### Diagnosis Steps
1. **Memory Distribution Analysis**
   ```dart
   final debugInfo = videoManager.getDebugInfo();
   print('Total videos: ${debugInfo['totalVideos']}');
   print('Controllers: ${debugInfo['activeControllers']}');
   print('Memory estimate: ${debugInfo['estimatedMemoryMB']}MB');
   
   // Check for controller leaks
   final readyVideos = debugInfo['readyVideos'];
   final controllers = debugInfo['activeControllers'];
   if (controllers > readyVideos) {
     print('WARNING: More controllers than ready videos - possible leak');
   }
   ```

2. **Historical Analysis**
   ```dart
   final memoryTrend = performanceMonitor.getAnalytics().memoryUsage;
   print('Memory trend: ${memoryTrend.trend.direction}');
   print('Growth rate: ${memoryTrend.growthRateMBPerSecond} MB/s');
   ```

#### Solutions
1. **Immediate Memory Cleanup**
   ```dart
   // Force aggressive cleanup
   await videoManager.handleMemoryPressure();
   await videoManager.handleMemoryPressure(); // Second pass
   
   // Verify cleanup effectiveness
   final afterCleanup = videoManager.getDebugInfo();
   final memoryReduction = beforeMemory - afterCleanup['estimatedMemoryMB'];
   print('Memory reduced by: ${memoryReduction}MB');
   ```

2. **Configuration Adjustment**
   ```dart
   // Reduce memory footprint
   final lowMemoryConfig = VideoManagerConfig(
     maxVideos: 25,
     preloadAhead: 1,
     preloadBehind: 0,
     enableMemoryManagement: true,
   );
   ```

### Issue: Poor Preload Performance

#### Diagnosis Steps
1. **Preload Success Rate Analysis**
   ```dart
   final preloadStats = performanceMonitor.getAnalytics().preloadPerformance;
   print('Success rate: ${preloadStats.successRate}');
   print('Average time: ${preloadStats.averageTime.inMilliseconds}ms');
   print('Slow preloads: ${preloadStats.slowPreloads}');
   ```

2. **Network Quality Check**
   ```dart
   // Analyze preload failures by network type
   final cellularFailures = _getCellularPreloadFailures();
   final wifiFailures = _getWifiPreloadFailures();
   
   print('Cellular failure rate: ${cellularFailures.failureRate}');
   print('WiFi failure rate: ${wifiFailures.failureRate}');
   ```

#### Solutions
1. **Timeout Adjustment**
   ```dart
   // Increase timeouts for poor network conditions
   final adaptiveConfig = VideoManagerConfig(
     preloadTimeout: Duration(seconds: 20), // Increased from 10s
     maxRetries: 5, // Increased from 3
   );
   ```

2. **Preload Strategy Optimization**
   ```dart
   // Reduce preload aggressiveness
   final conservativeConfig = VideoManagerConfig(
     preloadAhead: 2, // Reduced from 3
     preloadBehind: 0, // Reduced from 1
   );
   ```

## Maintenance Procedures

### Daily Maintenance Tasks

#### Performance Health Check
```bash
#!/bin/bash
# daily_health_check.sh

echo "=== OpenVine Video System Health Check ==="
echo "Date: $(date)"

# Check memory usage trends
echo "Memory usage over last 24h:"
curl -s "https://api.openvine.co/metrics/memory?range=24h" | jq '.peak_memory_mb'

# Check error rates
echo "Error rates:"
curl -s "https://api.openvine.co/metrics/errors?range=24h" | jq '.error_rate'

# Check performance metrics
echo "Performance metrics:"
curl -s "https://api.openvine.co/metrics/performance?range=24h" | jq '.avg_preload_time_ms'

# Check A/B test health
echo "A/B test status:"
curl -s "https://api.openvine.co/metrics/ab-tests" | jq '.video_system_migration_v2'
```

#### Log Analysis
```bash
#!/bin/bash
# analyze_logs.sh

# Extract video system errors from last 24h
grep -E "(VideoManager|preload|memory_pressure)" /var/log/app.log | \
  grep "$(date -d '1 day ago' '+%Y-%m-%d')" | \
  awk '{print $4, $5}' | sort | uniq -c | sort -nr

# Check for memory warnings
grep "memory.*warning" /var/log/app.log | tail -10

# Look for performance degradation
grep "slow.*preload" /var/log/app.log | tail -10
```

### Weekly Maintenance Tasks

#### Performance Trend Analysis
```dart
class WeeklyAnalysis {
  static Future<void> generateWeeklyReport() async {
    final analytics = performanceMonitor.getAnalytics(
      timeRange: Duration(days: 7)
    );
    
    final report = {
      'week_ending': DateTime.now().toIso8601String(),
      'memory_usage': {
        'peak': analytics.memoryUsage.peak,
        'average': analytics.memoryUsage.average,
        'trend': analytics.memoryUsage.trend.direction.name,
      },
      'performance': {
        'preload_success_rate': analytics.preloadPerformance.successRate,
        'avg_preload_time': analytics.preloadPerformance.averageTime.inMilliseconds,
      },
      'errors': {
        'total_errors': analytics.errorAnalysis.totalErrors,
        'error_rate': analytics.errorAnalysis.errorRate,
        'top_errors': analytics.errorAnalysis.topErrors.take(5).toList(),
      },
      'recommendations': analytics.recommendations,
    };
    
    // Save report and send to team
    await _saveWeeklyReport(report);
    await _sendReportToTeam(report);
  }
}
```

#### A/B Test Review
```dart
class ABTestReview {
  static Future<void> reviewExperiments() async {
    final abTesting = ABTestingService.instance;
    
    for (final experiment in abTesting.getActiveExperiments()) {
      final results = abTesting.getExperimentResults(experiment.id);
      
      print('Experiment: ${experiment.name}');
      print('  Control users: ${results.controlUsers}');
      print('  Treatment users: ${results.treatmentUsers}');
      print('  Lift: ${results.liftPercentage.toStringAsFixed(1)}%');
      print('  Significant: ${results.isSignificant}');
      
      // Check if experiment should be graduated or stopped
      if (results.isSignificant && results.liftPercentage > 10) {
        print('  RECOMMENDATION: Graduate experiment to 100%');
      } else if (results.treatmentUsers > 1000 && !results.isSignificant) {
        print('  RECOMMENDATION: Consider stopping experiment');
      }
    }
  }
}
```

### Monthly Maintenance Tasks

#### Configuration Optimization
```dart
class ConfigurationOptimizer {
  static Future<void> optimizeConfigurations() async {
    // Analyze performance data from last month
    final monthlyAnalytics = performanceMonitor.getAnalytics(
      timeRange: Duration(days: 30)
    );
    
    // Generate configuration recommendations
    final recommendations = _generateConfigRecommendations(monthlyAnalytics);
    
    print('Monthly Configuration Recommendations:');
    for (final rec in recommendations) {
      print('${rec.parameter}: ${rec.currentValue} → ${rec.recommendedValue}');
      print('  Reason: ${rec.reason}');
      print('  Expected impact: ${rec.expectedImpact}');
    }
  }
}
```

## Deployment Procedures

### Pre-Deployment Checklist
- [ ] All tests passing (unit, integration, load tests)
- [ ] Performance benchmarks within acceptable range
- [ ] Memory usage tested under load
- [ ] A/B testing framework ready for gradual rollout
- [ ] Rollback procedures tested and ready
- [ ] Monitoring and alerting configured
- [ ] Team notified of deployment window

### Deployment Steps
1. **Deploy to Staging**
   ```bash
   # Deploy to staging environment
   ./deploy.sh staging
   
   # Run full test suite
   flutter test test/integration/
   flutter test test/load_testing/
   
   # Performance verification
   flutter test test/load_testing/performance_benchmarks.dart
   ```

2. **Gradual Production Rollout**
   ```dart
   // Start with 1% rollout
   ABTestingService.instance.updateRemoteConfig('video_system_rollout_percentage', 1);
   
   // Monitor for 2 hours
   await Future.delayed(Duration(hours: 2));
   
   // Check health metrics
   final health = await _checkSystemHealth();
   if (health.isHealthy) {
     // Increase to 5%
     ABTestingService.instance.updateRemoteConfig('video_system_rollout_percentage', 5);
   }
   ```

3. **Monitor Deployment**
   ```dart
   // Enhanced monitoring during deployment
   final deploymentMonitor = DeploymentMonitor(
     startTime: DateTime.now(),
     rolloutPercentage: 1,
   );
   
   deploymentMonitor.startMonitoring();
   
   // Alert on any degradation
   deploymentMonitor.onHealthDegradation = () {
     _executeEmergencyRollback();
   };
   ```

### Post-Deployment Verification
```dart
class PostDeploymentVerification {
  static Future<bool> verifyDeployment() async {
    // Check all critical metrics
    final checks = [
      _checkMemoryUsage(),
      _checkPreloadSuccessRate(),
      _checkCrashRate(),
      _checkUserEngagement(),
    ];
    
    final results = await Future.wait(checks);
    final allPassed = results.every((result) => result);
    
    if (allPassed) {
      print('✅ Deployment verification passed');
      return true;
    } else {
      print('❌ Deployment verification failed');
      return false;
    }
  }
}
```

## Alerting and Escalation

### Alert Severity Levels

#### P0 - Critical (Immediate Response Required)
- System crashes affecting >10% of users
- Memory usage >1GB sustained
- Complete video loading failure
- **Response Time**: 15 minutes
- **Escalation**: Page on-call engineer immediately

#### P1 - High (Response Within 1 Hour)
- Memory usage >500MB sustained
- Video load success rate <70%
- Crash rate >3% above baseline
- **Response Time**: 1 hour
- **Escalation**: Slack alert + email to team

#### P2 - Medium (Response Within 4 Hours)
- Performance degradation >20%
- A/B test showing negative impact
- Memory usage trending upward
- **Response Time**: 4 hours
- **Escalation**: Email to team

### Escalation Procedures

#### On-Call Rotation
```yaml
# oncall_schedule.yml
week_1:
  primary: engineer_a@openvine.co
  secondary: engineer_b@openvine.co
  
week_2:
  primary: engineer_b@openvine.co
  secondary: engineer_c@openvine.co
```

#### Contact Information
- **Slack Channel**: #video-system-alerts
- **PagerDuty**: nostrvine-video-system
- **Email Group**: video-team@openvine.co

### Alert Configuration

#### Memory Usage Alert
```yaml
alert: video_memory_high
query: avg(video_memory_mb) > 500
for: 5m
severity: P1
message: "Video system memory usage is {{ $value }}MB (threshold: 500MB)"
runbook: "https://docs.openvine.co/runbooks/memory-usage"
```

#### Crash Rate Alert
```yaml
alert: video_crash_rate_high
query: rate(app_crashes[5m]) > 0.03
for: 2m
severity: P0
message: "Video system crash rate is {{ $value | humanizePercentage }} (threshold: 3%)"
runbook: "https://docs.openvine.co/runbooks/crash-rate"
```

#### Performance Alert
```yaml
alert: video_preload_slow
query: avg(preload_duration_ms) > 5000
for: 10m
severity: P2
message: "Video preload time is {{ $value }}ms (threshold: 5000ms)"
runbook: "https://docs.openvine.co/runbooks/performance"
```

## Appendix

### Useful Commands

#### System Health Check
```bash
# Quick system status
curl -X GET https://api.openvine.co/health/video-system

# Detailed debug information
curl -X GET https://api.openvine.co/debug/video-manager

# Export performance data
curl -X GET "https://api.openvine.co/metrics/export?range=1h" > performance_data.json
```

#### Emergency Recovery
```bash
# Emergency memory cleanup
curl -X POST https://api.openvine.co/admin/memory-pressure

# Disable new video system
curl -X POST https://api.openvine.co/admin/feature-flags \
  -d '{"new_video_manager": false}'

# Reset A/B test rollout
curl -X POST https://api.openvine.co/admin/ab-tests \
  -d '{"video_system_migration_v2": {"percentage": 0}}'
```

### Reference Documentation
- [Architecture Overview](./ARCHITECTURE.md)
- [Performance Monitoring Setup](./PERFORMANCE_MONITORING_SETUP.md)
- [A/B Testing Guide](./AB_TESTING_SETUP_GUIDE.md)
- [Migration Guide](./MIGRATION_AND_ROLLBACK_GUIDE.md)
- [Load Testing Procedures](../test/load_testing/README.md)

---

**Document Version**: 1.0  
**Last Updated**: 2024-12-16  
**Owner**: Video Engineering Team  
**Review Cycle**: Monthly