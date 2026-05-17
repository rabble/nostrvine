// ABOUTME: Widget tests for MessageBubble.
// ABOUTME: Tests rendering of message text, timestamp visibility,
// ABOUTME: alignment for sent vs received messages, URL linkification,
// ABOUTME: and long-press callback.

import 'dart:async';

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

      Widget buildWithVideoMessage({required String message}) =>
          testMaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                timestamp: '2:30 PM',
                isSent: true,
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

      testWidgets('falls back to link text when video not found', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithVideoMessage(
            message: 'https://divine.video/video/unknown-id',
          ),
        );
        await tester.pumpAndSettle();

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(
                'https://divine.video/video/unknown-id',
              ),
        );
        expect(richTextFinder, findsOneWidget);
        expect(find.byType(VideoThumbnailWidget), findsNothing);
      });

      testWidgets('tapping unresolved Divine video link navigates in-app', (
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

        _linkRecognizer(
          tester,
          'https://divine.video/video/unknown-id',
        ).onTap!();
        await tester.pumpAndSettle();

        expect(find.text('video:unknown-id'), findsOneWidget);
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
  });
}
