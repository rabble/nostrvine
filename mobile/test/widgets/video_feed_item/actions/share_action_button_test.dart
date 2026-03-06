// ABOUTME: Tests for ShareActionButton widget
// ABOUTME: Verifies share icon renders, menu items display, and save/download
// ABOUTME: options appear correctly based on content ownership.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(ShareActionButton, () {
    const ownPubkey =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    const otherPubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';

    late VideoEvent testVideo;

    setUp(() {
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey: ownPubkey,
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
    });

    testWidgets('renders share icon button', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      expect(find.byType(ShareActionButton), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('renders $DivineIcon with shareFat icon', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();

      expect(
        divineIcons.any((icon) => icon.icon == DivineIconName.shareFat),
        isTrue,
        reason: 'Should render shareFat DivineIcon',
      );
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      // Find Semantics widget with share button label
      final semanticsFinder = find.bySemanticsLabel('Share video');
      expect(semanticsFinder, findsOneWidget);
    });

    group('share menu', () {
      MockAuthService createAuthenticatedMock(String pubkey) {
        final mockAuth = createMockAuthService();
        when(() => mockAuth.isAuthenticated).thenReturn(true);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkey);
        return mockAuth;
      }

      testWidgets('shows save options for own content', (tester) async {
        final mockAuth = createAuthenticatedMock(ownPubkey);
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            mockAuthService: mockAuth,
            mockUserProfileService: mockProfile,
          ),
        );

        // Tap the share button to open the menu
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        // Own content should see both save options
        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Save with Watermark'), findsOneWidget);
      });

      testWidgets(
        'shows Save Video for other user content',
        (tester) async {
          final mockAuth = createAuthenticatedMock(otherPubkey);
          final mockProfile = createMockUserProfileService();

          // Video pubkey is ownPubkey, but logged in as otherPubkey
          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(body: ShareActionButton(video: testVideo)),
              mockAuthService: mockAuth,
              mockUserProfileService: mockProfile,
            ),
          );

          await tester.tap(find.byType(IconButton));
          await tester.pumpAndSettle();

          // Other user's content should not show Save to Gallery
          expect(find.text('Save to Gallery'), findsNothing);
          // Should show "Save Video" instead of "Save with Watermark"
          expect(find.text('Save Video'), findsOneWidget);
        },
      );

      testWidgets(
        'shows Save Video when not authenticated',
        (tester) async {
          final mockAuth = createMockAuthService();
          final mockProfile = createMockUserProfileService();

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(body: ShareActionButton(video: testVideo)),
              mockAuthService: mockAuth,
              mockUserProfileService: mockProfile,
            ),
          );

          await tester.tap(find.byType(IconButton));
          await tester.pumpAndSettle();

          // Unauthenticated should not see Save to Gallery
          expect(find.text('Save to Gallery'), findsNothing);
          expect(find.text('Save Video'), findsOneWidget);
        },
      );

      testWidgets('shows standard menu items', (tester) async {
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            mockUserProfileService: mockProfile,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('Share with user'), findsOneWidget);
        expect(find.text('Add to bookmarks'), findsOneWidget);
        expect(find.text('More options'), findsOneWidget);
      });
    });
  });
}
