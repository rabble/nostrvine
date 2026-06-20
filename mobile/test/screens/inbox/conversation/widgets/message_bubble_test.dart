// ABOUTME: Widget tests for MessageBubble.
// ABOUTME: Tests rendering of message text, timestamp visibility,
// ABOUTME: alignment for sent vs received messages, URL linkification,
// ABOUTME: and long-press callback.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

import '../../../../helpers/test_provider_overrides.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testEventId =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

GoRouter _messageRouter(String message) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: MessageBubble(
            message: message,
            timestamp: '2:30 PM',
            isSent: true,
          ),
        ),
      ),
      GoRoute(
        path: '/profile/:npub',
        builder: (context, state) =>
            Scaffold(body: Text('profile:${state.pathParameters['npub']}')),
      ),
      GoRoute(
        path: '/video/:id',
        builder: (context, state) =>
            Scaffold(body: Text('video:${state.pathParameters['id']}')),
      ),
    ],
  );
}

Widget _routerTestApp(
  GoRouter router, {
  List<dynamic>? additionalOverrides,
  MockNostrClient? mockNostrService,
}) {
  return testProviderScope(
    additionalOverrides: additionalOverrides,
    mockNostrService: mockNostrService,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

TapGestureRecognizer _linkRecognizer(WidgetTester tester, String linkText) {
  final richText = tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(linkText),
    ),
  );
  final recognizer = _findRecognizer(richText.text, linkText);
  expect(recognizer, isNotNull);
  return recognizer!;
}

TapGestureRecognizer? _findRecognizer(InlineSpan span, String linkText) {
  if (span is TextSpan) {
    final recognizer = span.recognizer;
    if (span.text == linkText && recognizer is TapGestureRecognizer) {
      return recognizer;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      final match = _findRecognizer(child, linkText);
      if (match != null) return match;
    }
  }
  return null;
}

void main() {
  final strings = AppLocalizationsEn();

  group(MessageBubble, () {
    group('renders', () {
      testWidgets('renders message text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('Hello there'), findsOneWidget);
      });

      testWidgets('renders timestamp when isFirstInGroup is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('2:30 PM'), findsOneWidget);
      });

      testWidgets('does not render timestamp when isFirstInGroup is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
                isFirstInGroup: false,
              ),
            ),
          ),
        );

        expect(find.text('2:30 PM'), findsNothing);
      });

      testWidgets('aligns right for sent messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Sent message',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(AlignmentDirectional.centerEnd));
      });

      testWidgets('aligns left for received messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Received message',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(AlignmentDirectional.centerStart));
      });

      testWidgets(
        'renders without crashing when message contains an unpaired '
        'UTF-16 surrogate',
        (tester) async {
          // Sender-controlled NIP-17 rumor bodies can deliver malformed
          // UTF-16 via JSON \uXXXX escapes; the renderer asserts on
          // well-formed UTF-16, so MessageBubble must sanitize before
          // painting. See https://github.com/divinevideo/divine-mobile/issues/4463.
          final malformed = 'before${String.fromCharCode(0xD83D)}after';
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageBubble(
                  message: malformed,
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('beforeafter'), findsOneWidget);
        },
      );
    });

    group('delivery status indicator', () {
      // Per-status icon mapping for sent bubbles. The bubble omits the
      // indicator entirely when `deliveryStatus == delivered`, so a
      // fully-delivered sent message renders identically to a received
      // message in this respect.

      testWidgets('renders no indicator for delivered status', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Done',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.access_time), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });

      testWidgets('renders clock icon while pending', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'In flight',
                timestamp: '2:30 PM',
                isSent: true,
                deliveryStatus: DmDeliveryStatus.pending,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(
          find.byTooltip(strings.dmStatusPending),
          findsOneWidget,
        );
      });

      testWidgets(
        'renders warning icon for deliveredSelfFailed status',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageBubble(
                  message: 'Half-delivered',
                  timestamp: '2:30 PM',
                  isSent: true,
                  deliveryStatus: DmDeliveryStatus.deliveredSelfFailed,
                ),
              ),
            ),
          );

          expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
          expect(
            find.byTooltip(strings.dmStatusDeliveredSelfFailed),
            findsOneWidget,
          );
        },
      );

      testWidgets('renders error icon for failed status', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Failed send',
                timestamp: '2:30 PM',
                isSent: true,
                deliveryStatus: DmDeliveryStatus.failed,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(
          find.byTooltip(strings.dmStatusFailed),
          findsOneWidget,
        );
      });

      testWidgets(
        'does not render indicator for received messages even when '
        'a non-delivered status is passed',
        (tester) async {
          // Received bubbles never read the outgoing queue; the parameter
          // defaults to delivered for them, and the caller in
          // `_MessageList` short-circuits the BlocSelector. Defensively
          // ignore the parameter when isSent is false.
          await tester.pumpWidget(
            const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageBubble(
                  message: 'From them',
                  timestamp: '2:30 PM',
                  isSent: false,
                  deliveryStatus: DmDeliveryStatus.failed,
                ),
              ),
            ),
          );

          expect(find.byIcon(Icons.error_outline), findsNothing);
          expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
          expect(find.byIcon(Icons.access_time), findsNothing);
        },
      );
    });

    group('URL linkification', () {
      testWidgets('renders plain text without $RichText', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'No links here',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('No links here'), findsOneWidget);
      });

      testWidgets('renders URL as tappable rich text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Check https://divine.video/terms',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('https://divine.video'),
        );
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets('renders npub references as profile display names', (
        tester,
      ) async {
        final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);
        final profile = UserProfile(
          pubkey: _testHexPubkey,
          displayName: 'Alice Divine',
          rawData: const {},
          createdAt: DateTime.utc(2026, 5, 7),
          eventId: _testEventId,
        );

        await tester.pumpWidget(
          _routerTestApp(
            _messageRouter('Reported profile $npub'),
            additionalOverrides: [
              userProfileReactiveProvider(
                _testHexPubkey,
              ).overrideWith((ref) => Stream.value(profile)),
            ],
          ),
        );
        await tester.pump();

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('@Alice Divine'),
          ),
        );

        expect(richText.text.toPlainText(), isNot(contains(npub)));
        expect(_findRecognizer(richText.text, '@Alice Divine'), isNotNull);
      });

      testWidgets('routes nevent references to decoded event ids', (
        tester,
      ) async {
        final nevent = NIP19Tlv.encodeNevent(Nevent(id: _testEventId));

        await tester.pumpWidget(
          _routerTestApp(_messageRouter('Watch $nevent')),
        );
        await tester.pump();

        final recognizer = _linkRecognizer(
          tester,
          strings.clickableTextViewVideoLink,
        );
        recognizer.onTap!();
        await tester.pumpAndSettle();

        expect(find.text('video:$_testEventId'), findsOneWidget);
      });

      testWidgets('routes naddr references as stable video links', (
        tester,
      ) async {
        final naddr = NIP19Tlv.encodeNaddr(
          Naddr(id: 'stable-video', author: _testHexPubkey, kind: 34236),
        );

        await tester.pumpWidget(_routerTestApp(_messageRouter('Watch $naddr')));
        await tester.pump();

        final recognizer = _linkRecognizer(
          tester,
          strings.clickableTextViewVideoLink,
        );
        recognizer.onTap!();
        await tester.pumpAndSettle();

        expect(find.text('video:$naddr'), findsOneWidget);
      });

      testWidgets('pushes search route on @mention tap so back returns', (
        tester,
      ) async {
        // Regression: tapping a `@username` mention used to call `context.go`
        // and replace the stack, which broke back navigation from the
        // resulting search page in a DM conversation. Pushing preserves the
        // DM under the search so the user can pop back.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: MessageBubble(
                  message: 'Hey @hm21',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
            GoRoute(
              path: '/search-results/:query',
              builder: (context, state) => Scaffold(
                body: Text('search:${state.pathParameters['query']}'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(_routerTestApp(router));
        await tester.pump();

        _linkRecognizer(tester, '@hm21').onTap!();
        await tester.pumpAndSettle();

        expect(find.text('search:hm21'), findsOneWidget);
        expect(router.canPop(), isTrue);
      });

      testWidgets('URL span has $TapGestureRecognizer', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit https://example.com today',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('https://example.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        // Text.rich wraps our TextSpan in a parent; unwrap to reach
        // the actual URL spans built by _MessageText.
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan =
            innerSpan.children!.firstWhere(
                  (span) =>
                      span is TextSpan &&
                      (span.text?.contains('https://example.com') ?? false),
                )
                as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders multiple URLs in one message', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message:
                    'See https://divine.video/terms and '
                    'https://divine.video/support',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('divine.video'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpans = innerSpan.children!
            .whereType<TextSpan>()
            .where((s) => s.recognizer is TapGestureRecognizer)
            .toList();

        expect(urlSpans, hasLength(2));
      });

      testWidgets('renders bare domain as tappable link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit google.com for info',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('google.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan =
            innerSpan.children!.firstWhere(
                  (span) =>
                      span is TextSpan &&
                      (span.text?.contains('google.com') ?? false),
                )
                as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders bare domain with path as tappable link', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Check example.com/page today',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('example.com/page'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan =
            innerSpan.children!.firstWhere(
                  (span) =>
                      span is TextSpan &&
                      (span.text?.contains('example.com/page') ?? false),
                )
                as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders email address as tappable link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Email me at user@example.com please',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('user@example.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final emailSpan =
            innerSpan.children!.firstWhere(
                  (span) =>
                      span is TextSpan &&
                      (span.text?.contains('user@example.com') ?? false),
                )
                as TextSpan;

        expect(emailSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('URL-only message renders as link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'https://example.com/some-page',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('https://example.com'),
        );
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets('tapping Divine profile link navigates in-app', (
        tester,
      ) async {
        const npub =
            'npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9';
        final router = _messageRouter('https://divine.video/profile/$npub');
        addTearDown(router.dispose);

        await tester.pumpWidget(_routerTestApp(router));

        _linkRecognizer(tester, 'https://divine.video/profile/$npub').onTap!();
        await tester.pumpAndSettle();

        expect(find.text('profile:$npub'), findsOneWidget);
      });
    });

    group('video preview card', () {
      late _MockVideoEventService mockVideoEventService;
      late MockNostrClient mockNostrClient;

      final testVideo = VideoEvent(
        id:
            '0123456789abcdef0123456789abcdef'
            '0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789'
            'abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        title: 'My Cool Video',
      );

      setUp(() {
        mockVideoEventService = _MockVideoEventService();
        mockNostrClient = createMockNostrService();

        // Default stubs: nothing in cache.
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        when(
          () => mockVideoEventService.getVideoEventByVineId(any()),
        ).thenReturn(null);
        // Stub fetchEventById for video link preview lookups.
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) async => null);
      });

      Widget buildWithVideoMessage({
        required String message,
        DmSharedVideoRef? sharedVideoRef,
      }) => testMaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            timestamp: '2:30 PM',
            isSent: true,
            sharedVideoRef: sharedVideoRef,
          ),
        ),
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(
            mockVideoEventService,
          ),
        ],
      );

      testWidgets('shows loading spinner before video resolves', (
        tester,
      ) async {
        // Use a Completer that never completes so the cubit stays in
        // the loading state without leaving a pending Timer.
        final neverCompletes = Completer<Never>();
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) => neverCompletes.future);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        // Single pump to build the widget tree (don't settle).
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(VideoThumbnailWidget), findsNothing);
      });

      testWidgets('renders $VideoThumbnailWidget when video is in cache', (
        tester,
      ) async {
        when(
          () => mockVideoEventService.getVideoById('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('My Cool Video'), findsOneWidget);
      });

      testWidgets('renders from structured q-tag ref without a legacy URL', (
        tester,
      ) async {
        when(
          () => mockVideoEventService.getVideoEventByVineId('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message:
                'watch this\n'
                'nostr:naddr1qqxnzd3cxqmrzv3exgmr2wfeqy',
            sharedVideoRef: const DmSharedVideoRef(
              coordinateOrId: '34236:$_testHexPubkey:abc123',
              videoKind: DmSharedVideoKind.addressableShortVideo,
              relayHint: 'wss://relay.example',
              authorPubkey: _testHexPubkey,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('My Cool Video'), findsOneWidget);
        expect(find.text('watch this'), findsOneWidget);
        expect(find.textContaining('nostr:'), findsNothing);
        verify(
          () => mockVideoEventService.getVideoEventByVineId('abc123'),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('renders the shared-video bubble on a neutral dark frame', (
        tester,
      ) async {
        when(
          () => mockVideoEventService.getVideoById('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        await tester.pumpAndSettle();

        // The shared-video bubble uses VineTheme.neutral10 (#1B1C1C) — the
        // Figma `part/video thumbnail` share frame — not the bright sent-text
        // accent, so the thumbnail reads as a media card (isSent is true here).
        final bubble = tester.widget<Container>(
          find.ancestor(
            of: find.byType(VideoThumbnailWidget),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        );
        final decoration = bubble.decoration! as BoxDecoration;
        expect(decoration.color, VineTheme.neutral10);
        expect(decoration.color, isNot(VineTheme.primaryAccessible));
      });

      testWidgets('shared-video card matches Figma geometry', (tester) async {
        when(
          () => mockVideoEventService.getVideoById('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(message: 'https://divine.video/video/abc123'),
        );
        await tester.pumpAndSettle();

        // Thumbnail clips at 16 px corners (Figma `part/video thumbnail`
        // radius/16), not the previous 8 px.
        final clip = tester.widget<ClipRRect>(
          find.ancestor(
            of: find.byType(VideoThumbnailWidget),
            matching: find.byType(ClipRRect),
          ),
        );
        expect(clip.borderRadius, BorderRadius.circular(16));

        // Bubble frame uses 16 px horizontal / 12 px vertical padding
        // (Figma spacing/16 + spacing/12), matching the text bubbles.
        final bubble = tester.widget<Container>(
          find.ancestor(
            of: find.byType(VideoThumbnailWidget),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        );
        expect(
          bubble.padding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      });

      testWidgets('drops the nostr: citation line beneath the card', (
        tester,
      ) async {
        when(
          () => mockVideoEventService.getVideoById('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            // The q-tag share appends a NIP-21 citation after the URL; it must
            // not render as a redundant "View video" link beside the card.
            message:
                'https://divine.video/video/abc123\n'
                'nostr:naddr1qqxnzd3cxqmrzv3exgmr2wfeqy',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        final redundantLink = find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              (w.text.toPlainText().contains('nostr:') ||
                  w.text.toPlainText().contains(
                    AppLocalizationsEn().clickableTextViewVideoLink,
                  )),
        );
        expect(redundantLink, findsNothing);
      });

      testWidgets('shows the unavailable card when video not found', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithVideoMessage(
            message: 'https://divine.video/video/unknown-id',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().notificationsVideoUnavailable),
          findsOneWidget,
        );
        expect(find.byType(VideoThumbnailWidget), findsNothing);
        // The URL is no longer rendered as a tappable link.
        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(
                'https://divine.video/video/unknown-id',
              ),
        );
        expect(richTextFinder, findsNothing);
      });

      testWidgets('unresolved video card is not a tappable link', (
        tester,
      ) async {
        final router = _messageRouter('https://divine.video/video/unknown-id');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _routerTestApp(
            router,
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // The unavailable card replaces the old tappable link — nothing to
        // tap, so navigation never happens.
        expect(
          find.text(AppLocalizationsEn().notificationsVideoUnavailable),
          findsOneWidget,
        );
        expect(find.text('video:unknown-id'), findsNothing);
      });

      testWidgets('preserves surrounding text alongside video preview', (
        tester,
      ) async {
        when(
          () => mockVideoEventService.getVideoById('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message:
                'hey check this out '
                'https://divine.video/video/abc123 what do you think?',
          ),
        );
        await tester.pumpAndSettle();

        // Preview card is rendered.
        expect(find.byType(VideoThumbnailWidget), findsOneWidget);

        // Surrounding text is preserved.
        expect(find.text('hey check this out'), findsOneWidget);
        expect(find.text('what do you think?'), findsOneWidget);
      });

      testWidgets('preserves text before video URL only', (tester) async {
        when(
          () => mockVideoEventService.getVideoById('abc123'),
        ).thenReturn(testVideo);

        await tester.pumpWidget(
          buildWithVideoMessage(
            message: 'check this https://divine.video/video/abc123',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoThumbnailWidget), findsOneWidget);
        expect(find.text('check this'), findsOneWidget);
      });

      testWidgets(
        'drops the share-template quoted title line ahead of the URL',
        (tester) async {
          // VideoSharingService composes the share body as
          //   [personal message?]
          //   "<title>"
          //   <blank>
          //   <URL>
          // The "<title>" line duplicates what the card's overlay
          // footer renders, so the bubble must NOT also show it as
          // bubble text. Pin that contract — without this, the title
          // can silently leak back above the thumbnail.
          when(
            () => mockVideoEventService.getVideoById('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message:
                  '"Test Vine Title"\n\n'
                  'https://divine.video/video/abc123',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('"Test Vine Title"'), findsNothing);
        },
      );

      testWidgets(
        'preserves the personal note when share body also carries a '
        'quoted title',
        (tester) async {
          // Real share format with a user-typed personal note. The note
          // must render under the thumbnail; the "<title>" line above
          // it (also part of the template) must NOT render.
          when(
            () => mockVideoEventService.getVideoById('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message:
                  'You have to watch this 😂\n\n'
                  '"Test Vine Title"\n\n'
                  'https://divine.video/video/abc123',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('You have to watch this 😂'), findsOneWidget);
          expect(find.text('"Test Vine Title"'), findsNothing);
        },
      );

      testWidgets(
        'drops a quoted title line even when the title itself contains '
        'embedded quotes',
        (tester) async {
          when(
            () => mockVideoEventService.getVideoById('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            buildWithVideoMessage(
              message:
                  '"Watch "Inception" trailer"\n\n'
                  'https://divine.video/video/abc123',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          expect(find.text('"Watch "Inception" trailer"'), findsNothing);
        },
      );
    });

    group('quoted video reply preview', () {
      late _MockVideoEventService mockVideoEventService;
      late MockNostrClient mockNostrClient;

      final testVideo = VideoEvent(
        id:
            '0123456789abcdef0123456789abcdef'
            '0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789'
            'abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        title: 'My Cool Video',
      );

      const quotedRef = DmSharedVideoRef(
        coordinateOrId: '34236:$_testHexPubkey:abc123',
        videoKind: DmSharedVideoKind.addressableShortVideo,
        relayHint: 'wss://relay.example',
        authorPubkey: _testHexPubkey,
      );

      setUp(() {
        mockVideoEventService = _MockVideoEventService();
        mockNostrClient = createMockNostrService();

        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        when(
          () => mockVideoEventService.getVideoEventByVineId(any()),
        ).thenReturn(null);
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) async => null);
      });

      Widget buildWithQuotedReply({
        required String message,
        DmSharedVideoRef? quotedVideoRef,
      }) => testMaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            timestamp: '2:30 PM',
            isSent: true,
            quotedVideoRef: quotedVideoRef,
          ),
        ),
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(
            mockVideoEventService,
          ),
        ],
      );

      testWidgets(
        'renders compact quoted thumbnail above the reply text and not the '
        'full share card',
        (tester) async {
          when(
            () => mockVideoEventService.getVideoEventByVineId('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'love this one',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          // The compact quoted preview renders the resolved video as a small
          // thumbnail bounded to 40x56, not the full 248x350 share card.
          expect(find.byType(VideoThumbnailWidget), findsOneWidget);
          final compactThumb = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 40 && w.height == 56,
          );
          expect(compactThumb, findsOneWidget);

          // No full 248x350 share-card SizedBox is present.
          final fullCard = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 248 && w.height == 350,
          );
          expect(fullCard, findsNothing);

          // The reply text renders below the quoted preview.
          expect(find.text('love this one'), findsOneWidget);
          final thumbCenter = tester
              .getCenter(find.byType(VideoThumbnailWidget))
              .dy;
          final textCenter = tester.getCenter(find.text('love this one')).dy;
          expect(thumbCenter, lessThan(textCenter));

          // The compact thumbnail carries its own small play badge (an 11px
          // glyph) overlaid on the thumbnail, not the full-size 32px badge —
          // so it reads as a neat chip with margin on the 40-wide thumb.
          final playIcon = tester.widget<DivineIcon>(
            find.byWidgetPredicate(
              (w) => w is DivineIcon && w.icon == DivineIconName.play,
            ),
          );
          expect(playIcon.size, 11);

          // The preview is pinned to a fixed width so the bubble doesn't
          // reflow when the cited reel resolves out of its loading skeleton.
          expect(
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 200),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'exposes the resolved quoted preview as a button with the reply hint',
        (tester) async {
          when(
            () => mockVideoEventService.getVideoEventByVineId('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'love this one',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          // The tappable preview carries button semantics + the reply hint,
          // co-located on the frame so the tap target is always announced.
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.button ?? false) &&
                  w.properties.label ==
                      AppLocalizationsEn().dmMessageBubbleVideoReplyHint,
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the full share card for a non-reply share '
        '(sharedVideoRef set, quotedVideoRef null)',
        (tester) async {
          when(
            () => mockVideoEventService.getVideoEventByVineId('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            testMaterialApp(
              home: const Scaffold(
                body: MessageBubble(
                  message: 'watch this',
                  timestamp: '2:30 PM',
                  isSent: true,
                  sharedVideoRef: quotedRef,
                ),
              ),
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videoEventServiceProvider.overrideWithValue(
                  mockVideoEventService,
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // The full share card renders a 248x350 thumbnail (default size),
          // not the compact 40x56 quoted thumbnail.
          final fullCard = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 248 && w.height == 350,
          );
          expect(fullCard, findsOneWidget);
          final thumbnail = tester.widget<VideoThumbnailWidget>(
            find.byType(VideoThumbnailWidget),
          );
          expect(thumbnail.width, isNull);
          expect(thumbnail.height, isNull);
        },
      );

      testWidgets(
        'renders the compact unavailable chip when the quoted video is '
        'not found',
        (tester) async {
          // No cache hit, no relay event → VideoLinkPreviewNotFound.
          await tester.pumpWidget(
            buildWithQuotedReply(
              message: 'still good though',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(AppLocalizationsEn().notificationsVideoUnavailable),
            findsOneWidget,
          );
          expect(find.byType(VideoThumbnailWidget), findsNothing);
          // The reply comment still renders alongside the unavailable chip.
          expect(find.text('still good though'), findsOneWidget);

          // The unavailable chip is pinned to the same fixed width as the
          // resolved card, so swapping states never reflows the bubble.
          expect(
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 200),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'strips the trailing nostr: citation line from the displayed reply '
        'text when quotedVideoRef is set',
        (tester) async {
          when(
            () => mockVideoEventService.getVideoEventByVineId('abc123'),
          ).thenReturn(testVideo);

          await tester.pumpWidget(
            buildWithQuotedReply(
              // The reply self-carries a NIP-21 citation of the quoted video on
              // the wire; it must not render in the bubble text.
              message:
                  'this is hilarious\n'
                  'nostr:naddr1qqxnzd3cxqmrzv3exgmr2wfeqy',
              quotedVideoRef: quotedRef,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('this is hilarious'), findsOneWidget);
          expect(find.textContaining('nostr:'), findsNothing);
        },
      );
    });

    group('long-press', () {
      testWidgets('calls onLongPress callback', (tester) async {
        var longPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'Long press me',
                timestamp: '2:30 PM',
                isSent: true,
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('Long press me'));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });

      testWidgets('does not crash when onLongPress is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageBubble(
                message: 'No callback',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('No callback'));
        await tester.pumpAndSettle();

        expect(find.text('No callback'), findsOneWidget);
      });
    });

    group('markdown rendering', () {
      /// Walks the rendered span tree and collects every TextSpan that
      /// satisfies [predicate]. Used to assert on the inline-style
      /// flags applied to the rendered content.
      List<TextSpan> spansMatching(
        WidgetTester tester,
        bool Function(TextSpan span) predicate,
      ) {
        final hits = <TextSpan>[];
        final richTexts = tester
            .widgetList<RichText>(find.byType(RichText))
            .toList();
        for (final richText in richTexts) {
          void visit(InlineSpan span) {
            if (span is TextSpan) {
              if (predicate(span)) hits.add(span);
              for (final child in span.children ?? const <InlineSpan>[]) {
                visit(child);
              }
            }
          }

          visit(richText.text);
        }
        return hits;
      }

      Widget bubble(String message, {bool isSent = true}) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: testProviderScope(
              child: MessageBubble(
                message: message,
                timestamp: '2:30 PM',
                isSent: isSent,
              ),
            ),
          ),
        );
      }

      testWidgets('bold span renders with FontWeight.w700', (tester) async {
        await tester.pumpWidget(bubble('say **hi** please'));

        final boldSpans = spansMatching(
          tester,
          (span) =>
              span.text == 'hi' && span.style?.fontWeight == FontWeight.w700,
        );
        expect(boldSpans, hasLength(1));
      });

      testWidgets('italic span renders with FontStyle.italic', (tester) async {
        await tester.pumpWidget(bubble('be _kind_ today'));

        final italicSpans = spansMatching(
          tester,
          (span) =>
              span.text == 'kind' && span.style?.fontStyle == FontStyle.italic,
        );
        expect(italicSpans, hasLength(1));
      });

      testWidgets('strikethrough span renders with lineThrough decoration', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('that is ~~wrong~~ now'));

        final strikeSpans = spansMatching(
          tester,
          (span) =>
              span.text == 'wrong' &&
              span.style?.decoration == TextDecoration.lineThrough,
        );
        expect(strikeSpans, hasLength(1));
      });

      testWidgets('inline code renders with monospace + translucent bg', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('run `flutter test` first'));

        final codeSpans = spansMatching(
          tester,
          (span) => span.text == 'flutter test',
        );
        expect(codeSpans, hasLength(1));
        final style = codeSpans.single.style!;
        // Chivo Mono comes through google_fonts so the fontFamily
        // string includes a hash suffix — match by prefix.
        expect(style.fontFamily, startsWith('ChivoMono'));
        expect(style.background, isNotNull);
      });

      testWidgets('received bubble uses a lighter code background', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('try `x()`', isSent: false));

        final codeSpan = spansMatching(
          tester,
          (span) => span.text == 'x()',
        ).single;
        final bgAlpha = codeSpan.style!.background!.color.a;
        // Received variant uses 0.10 alpha; sent uses 0.18. Match the
        // received bucket here.
        expect(bgAlpha, closeTo(0.10, 0.02));
      });

      testWidgets('snake_case identifiers do not italicize', (tester) async {
        await tester.pumpWidget(bubble('try foo_bar_baz today'));

        final italicSpans = spansMatching(
          tester,
          (span) =>
              (span.text?.contains('bar') ?? false) &&
              span.style?.fontStyle == FontStyle.italic,
        );
        expect(italicSpans, isEmpty);
      });

      testWidgets('unmatched ** does not crash and renders as literal', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('half **incomplete'));

        // No bold span emitted.
        final boldSpans = spansMatching(
          tester,
          (span) => span.style?.fontWeight == FontWeight.w700,
        );
        expect(boldSpans, isEmpty);
        // The literal markers reach the rendered text.
        expect(find.textContaining('**incomplete'), findsOneWidget);
      });

      testWidgets('plain message without markdown markers renders unchanged', (
        tester,
      ) async {
        await tester.pumpWidget(bubble('just regular text here'));

        // No span carries any of the markdown style overrides.
        expect(
          spansMatching(
            tester,
            (span) => span.style?.fontWeight == FontWeight.w700,
          ),
          isEmpty,
        );
        expect(
          spansMatching(
            tester,
            (span) => span.style?.fontStyle == FontStyle.italic,
          ),
          isEmpty,
        );
        expect(
          spansMatching(
            tester,
            (span) => span.style?.decoration == TextDecoration.lineThrough,
          ),
          isEmpty,
        );
        expect(find.textContaining('just regular text here'), findsOneWidget);
      });
    });
  });
}
