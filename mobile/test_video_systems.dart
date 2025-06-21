// ABOUTME: Quick test script to determine which video system is running and compare performance
// ABOUTME: Run this with: dart test_video_systems.dart

import 'dart:io';
import 'lib/utils/video_system_tester.dart';
import 'lib/models/video_event.dart';

/// Quick test to determine which video system provides better performance
void main() async {
  print('🎬 NostrVine Video System Performance Test');
  print('═' * 50);
  
  try {
    final tester = VideoSystemTester();
    
    // Run comparison test
    print('⏳ Starting performance comparison test...');
    print('   This will test both VideoManagerService and VideoCacheService');
    print('   with the same set of videos to see which performs better.\n');
    
    final results = await tester.runComparisonTest();
    
    print('\n📋 TEST SUMMARY:');
    print('═' * 30);
    
    for (final entry in results.entries) {
      final name = entry.key;
      final result = entry.value;
      
      print('\n$name:');
      print('  Success Rate: ${result.successRate.toStringAsFixed(1)}%');
      print('  Avg Load Time: ${result.averageLoadTime.toStringAsFixed(1)}ms');
      print('  Videos Loaded: ${result.videosLoaded}/${result.videosLoaded + result.videosFailed}');
      print('  Memory Usage: ${result.averageMemoryMB.toStringAsFixed(1)}MB');
    }
    
    // Determine current app behavior
    print('\n🔍 CURRENT APP ANALYSIS:');
    print('═' * 25);
    print('Based on the code analysis:');
    print('• VideoFeedProvider creates both VideoCacheService AND VideoManagerService');
    print('• VideoFeedItem receives controllers from BOTH systems');
    print('• The app is currently running in HYBRID mode');
    print('• Both systems may be processing videos simultaneously');
    
    print('\n💡 RECOMMENDATIONS:');
    print('═' * 18);
    
    if (results.containsKey('VideoManager') && results.containsKey('VideoCache')) {
      final managerResult = results['VideoManager']!;
      final cacheResult = results['VideoCache']!;
      
      if (managerResult.successRate > cacheResult.successRate + 10) {
        print('✅ VideoManagerService performs significantly better');
        print('   → Complete the migration to VideoManagerService');
        print('   → Remove VideoCacheService from VideoFeedProvider');
      } else if (cacheResult.successRate > managerResult.successRate + 10) {
        print('⚠️  VideoCacheService performs better');
        print('   → The legacy system is more stable');
        print('   → Optimize VideoManagerService before migrating');
      } else {
        print('📊 Performance is similar between systems');
        print('   → Migration can proceed when ready');
        print('   → VideoManagerService offers better architecture');
      }
    }
    
    print('\n🏃 HOW TO TEST IN YOUR APP:');
    print('═' * 30);
    print('1. Triple-tap the top-right corner of the feed screen');
    print('2. This will show the debug overlay');
    print('3. Switch between systems and observe:');
    print('   • Video loading speed');
    print('   • Memory usage');
    print('   • Success rates');
    print('4. The debug overlay shows real-time metrics');
    
    print('\n🔧 TO USE PURE SYSTEMS:');
    print('═' * 22);
    print('For VideoManagerService only:');
    print('  → Remove videoCacheService from VideoFeedItem');
    print('  → Use only videoController from VideoManager');
    print('');
    print('For VideoCacheService only:');
    print('  → Remove VideoManager from VideoFeedProvider');
    print('  → Use only legacy videoCacheService');
    
  } catch (e) {
    print('❌ Test failed: $e');
    exit(1);
  }
}