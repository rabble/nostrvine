// ABOUTME: Tests for MoreActionButton widget and _VideoMoreMenu
// ABOUTME: Verifies moderation actions (report, mute, block) and debug tools

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/video_feed_item/actions/more_action_button.dart';

import '../../../helpers/test_provider_overrides.dart';
@GenerateMocks([ContentBlocklistService, MuteService])
import 'more_action_button_test.mocks.dart';

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

  group('VideoMoreMenu', () {
    late MockContentBlocklistService mockBlocklistService;
    late MockMuteService mockMuteService;
    late MockNostrClient mockNostrClient;

    setUp(() {
      mockBlocklistService = MockContentBlocklistService();
      mockMuteService = MockMuteService();
      mockNostrClient = createMockNostrService();
      // Stub publicKey so _handleBlock can access it
      mocktail
          .when(() => mockNostrClient.publicKey)
          .thenReturn('test_pubkey_hex');
    });

    Widget buildMenuWidget({bool debugToolsEnabled = false}) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: MoreActionButton(video: testVideo)),
          ),
        ],
      );

      return testProviderScope(
        mockUserProfileService: createMockUserProfileService(),
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          contentBlocklistServiceProvider.overrideWith(
            (ref) => mockBlocklistService,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
          isFeatureEnabledProvider(
            FeatureFlag.debugTools,
          ).overrideWithValue(debugToolsEnabled),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('renders moderation menu items', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

      // Tap the MoreActionButton to open its bottom sheet
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Report content'), findsOneWidget);
      expect(find.textContaining('Mute'), findsOneWidget);
      expect(find.textContaining('Block'), findsOneWidget);
    });

    testWidgets('hides debug tools when feature flag is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      expect(find.text('View Nostr event JSON'), findsNothing);
      expect(find.text('Copy Nostr event ID'), findsNothing);
    });

    testWidgets('shows debug tools when feature flag is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildMenuWidget(debugToolsEnabled: true));
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      expect(find.text('View Nostr event JSON'), findsOneWidget);
      expect(find.text('Copy Nostr event ID'), findsOneWidget);
    });

    testWidgets('tapping Report opens $ReportContentDialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Report content'));
      await tester.pumpAndSettle();

      expect(find.text('Report Content'), findsOneWidget);
      expect(find.text('Why are you reporting this content?'), findsOneWidget);
    });

    testWidgets('tapping Mute shows success snackbar on success', (
      tester,
    ) async {
      when(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mute'));
      await tester.pumpAndSettle();

      expect(find.text('User muted'), findsOneWidget);
    });

    testWidgets('tapping Mute shows error snackbar on failure', (tester) async {
      when(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mute'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to mute user'), findsOneWidget);
    });

    testWidgets('tapping Block shows confirmation dialog', (tester) async {
      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Block'));
      await tester.pumpAndSettle();

      expect(find.text('Block User?'), findsOneWidget);
      expect(
        find.text(
          "You won't see their content in feeds. "
          "They won't be notified.",
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
    });

    testWidgets('confirming Block calls blockUser and shows snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Block'));
      await tester.pumpAndSettle();

      // Tap the "Block" confirm button in the dialog
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();

      verify(
        mockBlocklistService.blockUser(
          testVideo.pubkey,
          ourPubkey: anyNamed('ourPubkey'),
        ),
      ).called(1);

      expect(find.text('User blocked'), findsOneWidget);
    });

    testWidgets('cancelling Block dismisses dialog without blocking', (
      tester,
    ) async {
      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Block'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        mockBlocklistService.blockUser(any, ourPubkey: anyNamed('ourPubkey')),
      );
    });

    testWidgets('tapping Copy Nostr event ID copies to clipboard', (
      tester,
    ) async {
      // Mock clipboard
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<String, dynamic>;
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildMenuWidget(debugToolsEnabled: true));
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Nostr event ID'));
      await tester.pumpAndSettle();

      expect(clipboardContent, isNotNull);
      expect(clipboardContent, startsWith('nevent1'));
      expect(find.text('Event ID copied to clipboard'), findsOneWidget);
    });
  });
}
