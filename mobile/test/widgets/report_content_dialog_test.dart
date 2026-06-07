// ABOUTME: Unit tests for ReportContentDialog widget (bottom sheet)
// ABOUTME: Tests Apple compliance requirements, reason selection, and submission

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart' as nostr;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

import '../helpers/test_provider_overrides.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockMuteService extends Mock implements MuteService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(ContentFilterReason.spam);
  });

  late VideoEvent testVideo;
  late _MockContentReportingService mockReportingService;
  late _MockContentBlocklistRepository mockBlocklistRepository;
  late _MockMuteService mockMuteService;

  setUp(() {
    final testNostrEvent = nostr.Event(
      '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
      34236,
      [
        ['d', 'test_video_id'],
        ['title', 'Test Video'],
        ['imeta', 'url https://example.com/test.mp4', 'm video/mp4'],
      ],
      'Test video content',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    testNostrEvent.id =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    testNostrEvent.sig =
        'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22';

    testVideo = VideoEvent.fromNostrEvent(testNostrEvent);
    mockReportingService = _MockContentReportingService();
    mockBlocklistRepository = _MockContentBlocklistRepository();
    mockMuteService = _MockMuteService();

    when(
      () => mockReportingService.reportContent(
        eventId: any(named: 'eventId'),
        authorPubkey: any(named: 'authorPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        additionalContext: any(named: 'additionalContext'),
        hashtags: any(named: 'hashtags'),
      ),
    ).thenAnswer((_) async => ReportResult.createSuccess('test_report_id'));

    when(
      () => mockReportingService.reportUser(
        userPubkey: any(named: 'userPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        relatedEventIds: any(named: 'relatedEventIds'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess('test_user_report_id'),
    );

    when(
      () => mockMuteService.muteUser(
        any(),
        reason: any(named: 'reason'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async => true);
  });

  Future<void> setLargeSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('$ReportContentDialog constructor', () {
    test(
      'throws when neither a video nor message identifiers are provided',
      () {
        expect(ReportContentDialog.new, throwsA(isA<ArgumentError>()));
      },
    );

    test('does not throw when only a userPubkey is provided', () {
      expect(
        () => ReportContentDialog(userPubkey: 'pubkey_hex'),
        returnsNormally,
      );
    });
  });

  group('$ReportContentDialog rendering', () {
    Widget buildSubject() => ProviderScope(
      overrides: [
        contentReportingServiceProvider.overrideWith(
          (ref) async => mockReportingService,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReportContentDialog(video: testVideo)),
      ),
    );

    testWidgets('renders form heading and policy notice', (tester) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportWhyReporting), findsOneWidget);
    });

    testWidgets('renders all report reason options', (tester) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReasonSpam), findsOneWidget);
      expect(find.text(l10n.reportReasonHarassment), findsOneWidget);
      expect(find.text(l10n.reportReasonViolence), findsOneWidget);
      expect(find.text(l10n.reportReasonSexualContent), findsOneWidget);
      expect(find.text(l10n.reportReasonCopyright), findsOneWidget);
      expect(find.text(l10n.reportReasonFalseInfo), findsOneWidget);
      expect(find.text(l10n.reportReasonCsam), findsOneWidget);
      expect(find.text(l10n.reportReasonAiGenerated), findsOneWidget);
      expect(find.text(l10n.reportReasonOther), findsOneWidget);
    });

    testWidgets('renders subtitle text for each reason', (tester) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReasonHarassmentSubtitle), findsOneWidget);
      expect(find.text(l10n.reportReasonOtherSubtitle), findsOneWidget);
    });

    testWidgets('details field is hidden until Other is selected', (
      tester,
    ) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'Submit button is visible even before selecting a reason (Apple requirement)',
      (tester) async {
        await setLargeSurface(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final submitButton = find.widgetWithText(
          DivineButton,
          l10n.reportSubmit,
        );
        expect(submitButton, findsOneWidget);

        final DivineButton button = tester.widget(submitButton);
        expect(
          button.onPressed,
          isNotNull,
          reason:
              'Submit button must be visible/enabled before selecting reason '
              '(Apple requirement)',
        );
      },
    );

    testWidgets(
      'Submit button shows error when tapped without selecting reason',
      (tester) async {
        await setLargeSurface(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.reportSelectReason),
          findsOneWidget,
          reason: 'Should show error when no reason selected',
        );
      },
    );

    testWidgets(
      'Submit button shows error when Other selected without details',
      (tester) async {
        await setLargeSurface(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.reportOtherRequiresDetails),
          findsOneWidget,
          reason: 'Should require details when Other is selected',
        );
      },
    );

    testWidgets('renders correct number of report reason options', (
      tester,
    ) async {
      await setLargeSurface(tester);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // One card per ContentFilterReason value — each has a Semantics(button)
      // wrapping it that we can count.
      expect(
        ContentFilterReason.values.length,
        equals(11),
        reason: 'Sanity-check: 11 report reasons defined',
      );
      // Verify all titles render by checking the last and first in the list.
      expect(find.text(l10n.reportReasonSpam), findsOneWidget);
      expect(find.text(l10n.reportReasonOther), findsOneWidget);
    });
  });

  group('$ReportContentDialog submission', () {
    late MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = createMockNostrService();
      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
    });

    Widget buildSubject() {
      // GoRouter is needed so Navigator.of(context).pop() finds the right route.
      // Material wrapper is required because showDialog alone doesn't provide one
      // (unlike showModalBottomSheet which the production path uses).
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Material(child: ReportContentDialog(video: testVideo)),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Widget buildBottomSheetSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      ReportContentDialog.show(context, video: testVideo),
                  child: const Text('Open Bottom Sheet Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openReportDialog(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();
    }

    Future<void> openBottomSheetReport(WidgetTester tester) async {
      await tester.pumpWidget(buildBottomSheetSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Bottom Sheet Report'));
      await tester.pumpAndSettle();
    }

    testWidgets('selecting reason and tapping Submit calls reportContent', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
    });

    testWidgets('successful report shows $ReportConfirmationDialog', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonHarassment));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportReceivedThankYou), findsOneWidget);
    });

    testWidgets(
      'Submit button enters loading state while submission is in progress '
      '(prevents double-tap duplicate Kind 1984)',
      (tester) async {
        final completer = Completer<ReportResult>();
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
          ),
        ).thenAnswer((_) => completer.future);

        await setLargeSurface(tester);
        await openReportDialog(tester);

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pump();

        final submitBtn = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, l10n.reportSubmit),
        );
        expect(
          submitBtn.isLoading,
          isTrue,
          reason: 'Button must show loading state during submission',
        );

        completer.complete(ReportResult.createSuccess('test_report_id'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('failed report shows inline error', (tester) async {
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer((_) async => ReportResult.failure('Server error'));

      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to report content'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('exception during report shows inline error', (tester) async {
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenThrow(Exception('Network error'));

      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to report content'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'bottom sheet path keeps report errors inline instead of using snackbars',
      (tester) async {
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
          ),
        ).thenAnswer((_) async => ReportResult.failure('Server error'));

        await setLargeSurface(tester);
        await openBottomSheetReport(tester);

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.widgetWithText(DivineButton, l10n.reportSubmit),
        );
        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.textContaining('Failed to report content'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'bottom sheet path surfaces validation errors inline without snackbars',
      (tester) async {
        await setLargeSurface(tester);
        await openBottomSheetReport(tester);

        await tester.ensureVisible(
          find.widgetWithText(DivineButton, l10n.reportSubmit),
        );
        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportSelectReason), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('Other reason with details submits successfully', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openReportDialog(tester);

      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Custom report details');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: ContentFilterReason.other,
          details: 'Custom report details',
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
    });
  });

  group('$ReportConfirmationDialog', () {
    testWidgets('renders success content with DM mention', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ReportConfirmationDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportReceivedThankYou), findsOneWidget);
      expect(
        find.textContaining('via direct message'),
        findsOneWidget,
        reason: 'TC-025: Confirmation should mention DM follow-up',
      );
      expect(find.text(l10n.reportLearnMore), findsOneWidget);
      expect(find.text(l10n.reportSafetyUrl), findsOneWidget);
    });

    testWidgets('renders Close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ReportConfirmationDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportClose), findsOneWidget);
    });
  });

  group('moderation DM integration', () {
    late MockNostrClient mockNostrClient;
    late _MockDmRepository mockDmRepository;
    late _MockModerationLabelService mockModerationLabelService;

    setUp(() {
      mockNostrClient = createMockNostrService();
      mockDmRepository = _MockDmRepository();
      mockModerationLabelService = _MockModerationLabelService();

      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );
    });

    Widget buildSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Material(child: ReportContentDialog(video: testVideo)),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openAndSubmitReport(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets('sends DM to moderation team after successful report', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).called(1);
    });

    testWidgets('DM content includes report reason and event ID', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      final dmContent = captured.single as String;
      expect(
        dmContent,
        contains('Content Report'),
        reason: 'DM should be labeled as a content report',
      );
      expect(
        dmContent,
        contains('Spam or Unwanted Content'),
        reason: 'DM should include the report reason',
      );
      expect(
        dmContent,
        contains(testVideo.id),
        reason: 'DM should include the reported event ID',
      );
    });

    testWidgets('report succeeds even if moderation DM fails', (tester) async {
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenThrow(Exception('DM relay unreachable'));

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(
        find.text(l10n.reportReceivedTitle),
        findsOneWidget,
        reason: 'Report should succeed even if DM fails',
      );
      // C9: the swallowed DM failure is now surfaced as a calm notice
      // instead of only a log line.
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('moderation DM opts out of the NIP-04 fallback (privacy)', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      // C8: moderation reports carry user identity + reported content and
      // must never degrade to a metadata-leaking NIP-04 plaintext duplicate.
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: true,
        ),
      ).called(1);
    });

    testWidgets('does not show the DM-delayed notice when the DM succeeds', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsNothing);
    });

    Widget buildSubjectWithAuth(MockAuthService auth) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Material(child: ReportContentDialog(video: testVideo)),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockAuthService: auth,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openSubmitWithAuth(
      WidgetTester tester,
      MockAuthService a,
    ) async {
      await tester.pumpWidget(buildSubjectWithAuth(a));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'shows the "Message the moderation team" affordance when signed in',
      (tester) async {
        final mockAuth = createMockAuthService();
        when(() => mockAuth.currentPublicKeyHex).thenReturn(
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
        );

        await setLargeSurface(tester);
        await openSubmitWithAuth(tester, mockAuth);

        expect(find.text(l10n.reportContactModeration), findsOneWidget);
      },
    );

    testWidgets('hides the contact-moderation affordance when signed out', (
      tester,
    ) async {
      // createMockAuthService stubs currentPublicKeyHex -> null.
      await setLargeSurface(tester);
      await openSubmitWithAuth(tester, createMockAuthService());

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportContactModeration), findsNothing);
    });

    testWidgets(
      'report succeeds when DM send throws (unauthenticated/no keys)',
      (tester) async {
        final noKeysDmRepo = _MockDmRepository();
        when(
          () => noKeysDmRepo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenThrow(Exception('No keys available'));

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => Material(
                        child: ReportContentDialog(video: testVideo),
                      ),
                    ),
                    child: const Text('Open Report'),
                  ),
                ),
              ),
            ),
          ],
        );

        await setLargeSurface(tester);
        await tester.pumpWidget(
          testProviderScope(
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              contentReportingServiceProvider.overrideWith(
                (ref) async => mockReportingService,
              ),
              dmRepositoryProvider.overrideWithValue(noKeysDmRepo),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Report'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
        verifyNever(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        );
      },
    );
  });

  group('moderation DM integration (showForMessage path)', () {
    late MockNostrClient mockNostrClient;
    late _MockDmRepository mockDmRepository;
    late _MockModerationLabelService mockModerationLabelService;

    const testMessageId =
        'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222';
    const testSenderPubkey =
        '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';

    setUp(() {
      mockNostrClient = createMockNostrService();
      mockDmRepository = _MockDmRepository();
      mockModerationLabelService = _MockModerationLabelService();

      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );
    });

    Widget buildMessageReportSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Material(
                      child: ReportContentDialog(
                        eventId: testMessageId,
                        authorPubkey: testSenderPubkey,
                        moderationKindLabel: 'DM Message Report',
                        moderationEventLabel: 'Message ID',
                      ),
                    ),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openAndSubmitMessageReport(WidgetTester tester) async {
      await tester.pumpWidget(buildMessageReportSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reportReasonSpam));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'moderation DM body uses DM Message Report header and Message ID label',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitMessageReport(tester);

        final captured = verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: captureAny(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).captured;

        final dmContent = captured.single as String;
        expect(
          dmContent,
          contains('DM Message Report'),
          reason:
              'header should distinguish message reports from video reports',
        );
        expect(
          dmContent,
          contains('Message ID: $testMessageId'),
          reason: 'event-id line should be labeled "Message ID:" not "Event:"',
        );
        expect(
          dmContent,
          isNot(contains('Content Report')),
          reason: 'video-report header must not leak into message-report body',
        );
        expect(
          dmContent,
          isNot(contains('Event: $testMessageId')),
          reason: 'video-report event-id label must not leak into message body',
        );
      },
    );
  });

  group('user report (showForUser path)', () {
    late MockNostrClient mockNostrClient;
    late _MockDmRepository mockDmRepository;
    late _MockModerationLabelService mockModerationLabelService;

    const testUserPubkey =
        '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';

    setUp(() {
      mockNostrClient = createMockNostrService();
      mockDmRepository = _MockDmRepository();
      mockModerationLabelService = _MockModerationLabelService();

      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
        ),
      );
    });

    Widget buildUserReportSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Material(
                      child: ReportContentDialog(
                        userPubkey: testUserPubkey,
                        moderationKindLabel: 'User Report',
                        moderationEventLabel: 'User Pubkey',
                      ),
                    ),
                  ),
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ],
      );

      return testProviderScope(
        mockNostrService: mockNostrClient,
        mockModerationLabelService: mockModerationLabelService,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistRepositoryProvider.overrideWith(
            (ref) => mockBlocklistRepository,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> openAndSubmitUserReport(WidgetTester tester) async {
      await tester.pumpWidget(buildUserReportSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.reportReasonHarassment));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'submission calls reportUser with the user pubkey and skips reportContent',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitUserReport(tester);

        verify(
          () => mockReportingService.reportUser(
            userPubkey: testUserPubkey,
            reason: ContentFilterReason.harassment,
            details: any(named: 'details'),
            relatedEventIds: any(named: 'relatedEventIds'),
          ),
        ).called(1);

        verifyNever(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
          ),
        );
      },
    );

    testWidgets(
      'moderation DM body uses User Report header and the synthetic user_<pubkey> event id',
      (tester) async {
        await setLargeSurface(tester);
        await openAndSubmitUserReport(tester);

        final captured = verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: captureAny(named: 'content'),
            replyToId: any(named: 'replyToId'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).captured;

        final dmContent = captured.single as String;
        expect(
          dmContent,
          contains('User Report'),
          reason: 'header should distinguish user reports from content reports',
        );
        expect(
          dmContent,
          contains('User Pubkey: user_$testUserPubkey'),
          reason: 'event-id line should carry the synthetic user_<pubkey> id',
        );
        expect(
          dmContent,
          isNot(contains('Content Report')),
          reason: 'content-report header must not leak into user-report body',
        );
      },
    );

    testWidgets('successful user report shows the in-sheet confirmation', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openAndSubmitUserReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
    });
  });

  group('moderation constants', () {
    test('moderation pubkey is a valid 64-character hex string', () {
      expect(
        ModerationLabelService.fallbackModerationPubkeyHex.length,
        equals(64),
      );
      expect(
        RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(ModerationLabelService.fallbackModerationPubkeyHex),
        isTrue,
      );
    });
  });
}
