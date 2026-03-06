// ABOUTME: Tests for ShareActionButton widget
// ABOUTME: Verifies share icon renders, share sheet opens with correct sections,
// ABOUTME: and ownership-specific download actions display correctly.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
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

      expect(find.bySemanticsLabel('Share video'), findsOneWidget);
    });

    group('share menu', () {
      Widget buildShareButton({
        MockAuthService? mockAuth,
        MockUserProfileService? mockProfile,
      }) {
        final mockNostr = createMockNostrService();

        return testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
          mockAuthService: mockAuth,
          mockUserProfileService: mockProfile,
          mockNostrService: mockNostr,
          additionalOverrides: [
            followRepositoryProvider.overrideWith(
              (ref) => FollowRepository(
                nostrClient: mockNostr,
                indexerRelayUrls: [],
              ),
            ),
          ],
        );
      }

      MockAuthService createAuthenticatedMock(String pubkey) {
        final mockAuth = createMockAuthService();
        when(() => mockAuth.isAuthenticated).thenReturn(true);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkey);
        return mockAuth;
      }

      testWidgets('shows Share with section', (tester) async {
        final mockAuth = createMockAuthService();
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('Share with'), findsOneWidget);
      });

      testWidgets('shows Find people button', (tester) async {
        final mockAuth = createMockAuthService();
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('Find\npeople'), findsOneWidget);
      });

      testWidgets('shows More actions section', (tester) async {
        final mockAuth = createMockAuthService();
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('More actions'), findsOneWidget);
      });

      testWidgets('shows save options for own content', (tester) async {
        final mockAuth = createAuthenticatedMock(ownPubkey);
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Save with Watermark'), findsOneWidget);
        expect(find.text('Save Video'), findsNothing);
      });

      testWidgets('shows Save Video for other user content', (tester) async {
        final mockAuth = createAuthenticatedMock(otherPubkey);
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('Save to Gallery'), findsNothing);
        expect(find.text('Save with Watermark'), findsNothing);
        expect(find.text('Save Video'), findsOneWidget);
      });

      testWidgets('shows Save Video when not authenticated', (tester) async {
        final mockAuth = createMockAuthService();
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('Save to Gallery'), findsNothing);
        expect(find.text('Save with Watermark'), findsNothing);
        expect(find.text('Save Video'), findsOneWidget);
      });

      testWidgets('shows standard action items', (tester) async {
        final mockAuth = createMockAuthService();
        final mockProfile = createMockUserProfileService();

        await tester.pumpWidget(
          buildShareButton(mockAuth: mockAuth, mockProfile: mockProfile),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Share via'), findsOneWidget);
        expect(find.text('Report'), findsOneWidget);
      });
    });
  });
}
