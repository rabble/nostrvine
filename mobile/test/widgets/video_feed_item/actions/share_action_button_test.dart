// ABOUTME: Tests for ShareActionButton widget
// ABOUTME: Verifies share icon renders, share sheet opens with correct sections,
// ABOUTME: and standard action items display in the unified share sheet.

@Tags(['skip_very_good_optimization'])
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideoSharingService extends Mock implements VideoSharingService {}

void main() {
  group(ShareActionButton, () {
    const ownPubkey =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    late VideoEvent testVideo;
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;
    late _MockVideoSharingService mockVideoSharingService;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockVideoSharingService = _MockVideoSharingService();
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      mockProfileRepository = _MockProfileRepository();
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

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

    testWidgets('renders $DivineIcon with shareFatDuo icon', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();

      expect(
        divineIcons.any((icon) => icon.icon == DivineIconName.shareFatDuo),
        isTrue,
        reason: 'Should render shareFatDuo DivineIcon',
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
      testWidgets('shows Share with section', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('Share with'), findsOneWidget);
      });

      testWidgets('shows Find people button', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('Find\npeople'), findsOneWidget);
      });

      testWidgets('shows More actions section', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('More actions'), findsOneWidget);
      });

      testWidgets('shows standard action items', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Save Video'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Share via'), findsOneWidget);
        expect(find.text('Report'), findsOneWidget);
      });

      testWidgets('shows own-video download actions for owned content', (
        tester,
      ) async {
        final mockAuth = createMockAuthService();

        when(() => mockAuth.isAuthenticated).thenReturn(true);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(ownPubkey);

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              followRepositoryProvider.overrideWithValue(mockFollowRepository),
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Save with Watermark'), findsOneWidget);
      });
    });
  });
}
