// ABOUTME: Tests for VisibilityAwareVideo widget
// ABOUTME: Ensures proper integration with VideoVisibilityManager

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:openvine/widgets/visibility_aware_video.dart';
import 'package:openvine/services/video_visibility_manager.dart';

void main() {
  // Set up VisibilityDetector for testing
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 100);
  });
  
  group('VisibilityAwareVideo', () {
    late VideoVisibilityManager visibilityManager;
    
    setUp(() {
      visibilityManager = VideoVisibilityManager();
    });
    
    tearDown(() {
      visibilityManager.dispose();
    });
    
    Widget createTestWidget({
      required String videoId,
      required Widget child,
      Function(VisibilityInfo)? onVisibilityChanged,
    }) {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: visibilityManager,
          child: Scaffold(
            body: VisibilityAwareVideo(
              videoId: videoId,
              onVisibilityChanged: onVisibilityChanged,
              child: child,
            ),
          ),
        ),
      );
    }
    
    testWidgets('should wrap child with VisibilityDetector', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          videoId: 'test-video',
          child: Container(
            height: 200,
            color: Colors.blue,
            child: const Text('Video Player'),
          ),
        ),
      );
      
      expect(find.byType(VisibilityDetector), findsOneWidget);
      expect(find.text('Video Player'), findsOneWidget);
    });
    
    testWidgets('should update visibility manager when visibility changes', (tester) async {
      const videoId = 'test-video';
      
      await tester.pumpWidget(
        createTestWidget(
          videoId: videoId,
          child: Container(height: 200),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // The widget might be visible or not depending on test environment
      // Just verify that the manager is tracking the video
      final info = visibilityManager.getVisibilityInfo(videoId);
      expect(info, isNotNull);
      expect(info!.videoId, equals(videoId));
      
      // Manually test visibility changes
      visibilityManager.updateVideoVisibility(videoId, 0.0);
      expect(visibilityManager.shouldVideoPlay(videoId), isFalse);
      
      visibilityManager.updateVideoVisibility(videoId, 0.8);
      expect(visibilityManager.shouldVideoPlay(videoId), isTrue);
    });
    
    testWidgets('should call onVisibilityChanged callback', (tester) async {
      VisibilityInfo? lastInfo;
      bool widgetDisposed = false;
      
      await tester.pumpWidget(
        createTestWidget(
          videoId: 'test-video',
          onVisibilityChanged: (info) {
            if (!widgetDisposed) {
              lastInfo = info;
            }
          },
          child: Container(height: 200),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // In test environment, visibility detector should have fired
      expect(lastInfo, isNotNull);
      
      // Mark as disposed before widget tree teardown
      widgetDisposed = true;
    });
    
    testWidgets('should provide visibility context to children', (tester) async {
      const videoId = 'test-video';
      bool? shouldPlayInChild;
      String? videoIdInChild;
      
      await tester.pumpWidget(
        createTestWidget(
          videoId: videoId,
          child: Builder(
            builder: (context) {
              shouldPlayInChild = context.shouldVideoPlay;
              videoIdInChild = context.visibilityVideoId;
              return Container();
            },
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(shouldPlayInChild, isNotNull);
      expect(videoIdInChild, equals(videoId));
    });
    
    testWidgets('should update when visibility manager changes', (tester) async {
      const videoId = 'test-video';
      
      await tester.pumpWidget(
        createTestWidget(
          videoId: videoId,
          child: Consumer<VideoVisibilityManager>(
            builder: (context, manager, _) {
              final shouldPlay = manager.shouldVideoPlay(videoId);
              return Text(shouldPlay ? 'Playing' : 'Paused');
            },
          ),
        ),
      );
      
      expect(find.text('Paused'), findsOneWidget);
      
      // Manually update visibility
      visibilityManager.updateVideoVisibility(videoId, 0.8);
      await tester.pump();
      
      expect(find.text('Playing'), findsOneWidget);
    });
  });
  
  group('VideoVisibilityMixin', () {
    testWidgets('should handle visibility changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => VideoVisibilityManager(),
            child: const _TestVideoWidget(videoId: 'test-video'),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      final state = tester.state<_TestVideoWidgetState>(find.byType(_TestVideoWidget));
      
      expect(state.isVisibleEnoughToPlay, isFalse);
      expect(state.playCount, equals(0));
      
      // Simulate visibility change
      state.updateVisibility(0.8);
      await tester.pump();
      
      expect(state.isVisibleEnoughToPlay, isTrue);
      expect(state.playCount, equals(1));
      
      // Simulate going invisible
      state.updateVisibility(0.2);
      await tester.pump();
      
      expect(state.isVisibleEnoughToPlay, isFalse);
      expect(state.pauseCount, equals(1));
    });
  });
}

// Test widget using VideoVisibilityMixin
class _TestVideoWidget extends StatefulWidget {
  final String videoId;
  
  const _TestVideoWidget({required this.videoId});
  
  @override
  State<_TestVideoWidget> createState() => _TestVideoWidgetState();
}

class _TestVideoWidgetState extends State<_TestVideoWidget> with VideoVisibilityMixin {
  int playCount = 0;
  int pauseCount = 0;
  
  @override
  String get videoId => widget.videoId;
  
  @override
  void onVisibilityChanged(bool shouldPlay) {
    if (shouldPlay) {
      playCount++;
    } else {
      pauseCount++;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: isVisibleEnoughToPlay ? Colors.green : Colors.red,
      child: Text(isVisibleEnoughToPlay ? 'Playing' : 'Paused'),
    );
  }
}