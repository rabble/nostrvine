// ABOUTME: Tests for VideoPublishTopBar widget
// ABOUTME: Validates back button and publish button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_publish/video_publish_top_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPublishTopBar Widget Tests', () {
    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          videoPublishProvider.overrideWith(
            () => TestVideoPublishNotifier(const VideoPublishProviderState()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const Scaffold(body: VideoPublishTopBar()),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('displays close button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.bySemanticsLabel('Back to clip editing'), findsOneWidget);
    });

    testWidgets('displays publish button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.bySemanticsLabel('Publish the video'), findsOneWidget);
    });

    testWidgets('publish button is tappable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final publishButton = find.bySemanticsLabel('Publish the video');

      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      expect(publishButton, findsOneWidget);
    });

    testWidgets('has SafeArea wrapper', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}

class TestVideoPublishNotifier extends VideoPublishNotifier {
  TestVideoPublishNotifier(this._state);
  final VideoPublishProviderState _state;

  @override
  VideoPublishProviderState build() => _state;

  @override
  Future<void> publishVideo(BuildContext context) async {}
}
