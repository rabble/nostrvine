// ABOUTME: Tests for MoreActionButton widget
// ABOUTME: Verifies the button renders correctly with proper semantics

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/actions/more_action_button.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  late VideoEvent testVideo;

  setUp(() {
    testVideo = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video',
    );
  });

  group(MoreActionButton, () {
    testWidgets('renders three-dots icon button', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: MoreActionButton(video: testVideo)),
        ),
      );

      expect(find.byType(MoreActionButton), findsOneWidget);

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();
      expect(
        divineIcons.any((icon) => icon.icon == DivineIconName.dotsThree),
        isTrue,
        reason: 'Should render dotsThree DivineIcon',
      );
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: MoreActionButton(video: testVideo)),
        ),
      );

      final semanticsFinder = find.bySemanticsLabel('More options');
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
