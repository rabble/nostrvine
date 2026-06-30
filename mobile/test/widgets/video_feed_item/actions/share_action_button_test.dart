// ABOUTME: Tests for ShareActionButton widget
// ABOUTME: Verifies share icon renders, share sheet opens with correct sections,
// ABOUTME: and standard action items display in the unified share sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

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
      expect(find.byType(GestureDetector), findsOneWidget);
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

    testWidgets('calls onInteracted before opening the share sheet', (
      tester,
    ) async {
      var interacted = false;
      final mockAuth = createMockAuthService();

      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: ShareActionButton(
              video: testVideo,
              onInteracted: () => interacted = true,
            ),
          ),
          additionalOverrides: [
            videoSharingServiceProvider.overrideWith(
              (ref) => mockVideoSharingService,
            ),
          ],
          mockAuthService: mockAuth,
          mockProfileRepository: mockProfileRepository,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(interacted, isTrue);
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

        await tester.tap(find.byType(GestureDetector));
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

        await tester.tap(find.byType(GestureDetector));
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

        await tester.tap(find.byType(GestureDetector));
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

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Save Video'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Share via'), findsOneWidget);
      });

      testWidgets('copy action responds when tapping the icon-label gap', (
        tester,
      ) async {
        final mockAuth = createMockAuthService();
        when(
          () => mockVideoSharingService.generateShareUrl(any()),
        ).thenReturn('https://divine.video/v/test');

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

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        final copyIcon = find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.linkSimple,
        );
        final copyLabel = find.text('Copy');
        expect(copyIcon, findsOneWidget);
        expect(copyLabel, findsOneWidget);

        final iconRect = tester.getRect(copyIcon);
        final labelRect = tester.getRect(copyLabel);

        await tester.tapAt(
          Offset(iconRect.center.dx, (iconRect.bottom + labelRect.top) / 2),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).shareCopiedPostLink,
          ),
          findsOneWidget,
        );
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
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
            mockFollowRepository: mockFollowRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Save with Watermark'), findsOneWidget);
      });

      testWidgets(
        'lifts message field above the keyboard when a recipient is selected',
        (tester) async {
          // Tall surface + dpr 1 so the short sheet stays bottom-anchored and
          // logical pixels equal physical pixels for the inset math.
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = const Size(1200, 6000);
          addTearDown(tester.view.reset);

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

          await tester.tap(find.byType(GestureDetector));
          await tester.pumpAndSettle();

          // Select a recipient so the message TextField is shown.
          final blocContext = tester.element(find.text('Share with'));
          blocContext.read<ShareSheetBloc>().add(
            const ShareSheetRecipientSelected(
              ShareableUser(
                pubkey:
                    'fedcba9876543210fedcba9876543210'
                    'fedcba9876543210fedcba9876543210',
                displayName: 'Alice',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);

          // Simulate the keyboard opening.
          const keyboardHeight = 320.0;
          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboardHeight,
          );
          await tester.pumpAndSettle();

          final logicalHeight =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          final keyboardTop = logicalHeight - keyboardHeight;

          // The field must sit above the keyboard, not behind it.
          expect(
            tester.getBottomLeft(find.byType(TextField)).dy,
            lessThanOrEqualTo(keyboardTop),
          );
        },
      );
    });
  });
}
