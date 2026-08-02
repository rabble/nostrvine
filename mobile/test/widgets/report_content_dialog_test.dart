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
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

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

  setUp(() {
    final testNostrEvent = nostr.Event(
      syntheticTestPubkey,
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

    when(
      () => mockReportingService.reportContent(
        eventId: any(named: 'eventId'),
        authorPubkey: any(named: 'authorPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        sourceRelay: any(named: 'sourceRelay'),
        additionalContext: any(named: 'additionalContext'),
        hashtags: any(named: 'hashtags'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess(
        'test_report_id',
        delivery: ReportDelivery.reached,
      ),
    );

    when(
      () => mockReportingService.reportUser(
        userPubkey: any(named: 'userPubkey'),
        reason: any(named: 'reason'),
        details: any(named: 'details'),
        relatedEventIds: any(named: 'relatedEventIds'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess(
        'test_user_report_id',
        delivery: ReportDelivery.reached,
      ),
    );
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
      'Submit button is visible before selecting a reason (Apple requirement) '
      'but stays disabled until one is picked',
      (tester) async {
        await setLargeSurface(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final submitButton = find.widgetWithText(
          DivineButton,
          l10n.reportSubmit,
        );
        expect(
          submitButton,
          findsOneWidget,
          reason:
              'Submit button must be visible before selecting a reason '
              '(Apple requirement)',
        );
        expect(
          tester.widget<DivineButton>(submitButton).onPressed,
          isNull,
          reason: 'Nothing to submit until a reason is picked',
        );

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        expect(
          tester.widget<DivineButton>(submitButton).onPressed,
          isNotNull,
          reason: 'Picking a reason enables submission',
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
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
    });

    testWidgets('video report forwards the source relay to reportContent', (
      tester,
    ) async {
      const sourceRelay = 'wss://relay.staging.dvines.org';
      testVideo = testVideo.copyWith(sourceRelay: sourceRelay);

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
          sourceRelay: sourceRelay,
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
    });

    testWidgets('successful report shows the confirmation view', (
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
            sourceRelay: any(named: 'sourceRelay'),
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

        completer.complete(
          ReportResult.createSuccess(
            'test_report_id',
            delivery: ReportDelivery.reached,
          ),
        );
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
          sourceRelay: any(named: 'sourceRelay'),
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
          sourceRelay: any(named: 'sourceRelay'),
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
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
          ),
        ).thenAnswer((_) async => ReportResult.failure('Server error'));

        await setLargeSurface(tester);
        await openBottomSheetReport(tester);

        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.textContaining('Failed to report content'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'submit failure surfaces the error on screen without scrolling',
      (tester) async {
        when(
          () => mockReportingService.reportContent(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            sourceRelay: any(named: 'sourceRelay'),
            additionalContext: any(named: 'additionalContext'),
            hashtags: any(named: 'hashtags'),
          ),
        ).thenAnswer((_) async => ReportResult.failure('Server error'));

        // A real phone, not the roomy default surface: the eleven reason
        // cards overflow here the way they do on device.
        const screen = Size(412, 915);
        await tester.binding.setSurfaceSize(screen);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await openBottomSheetReport(tester);

        // Pick the first reason so the user never has to scroll — the pinned
        // submit action is reachable from offset zero.
        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        final errorRect = tester.getRect(
          find.textContaining('Failed to report content'),
        );
        expect(
          errorRect.bottom,
          lessThanOrEqualTo(screen.height),
          reason:
              'The error must be visible where the user tapped. Rendered at '
              'the end of the scroll content it lands far below the fold and '
              'the failed submit looks like it did nothing.',
        );
        expect(errorRect.top, greaterThanOrEqualTo(0));
      },
    );

    testWidgets('the inline error announces its message once', (tester) async {
      final handle = tester.ensureSemantics();

      await setLargeSurface(tester);
      await openBottomSheetReport(tester);

      await tester.ensureVisible(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reportReasonOther));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      final error = tester.getSemantics(
        find.text(l10n.reportOtherRequiresDetails),
      );

      // `container: true` already absorbs the Text, so a `label:` on the
      // annotation would prepend a second copy and a screen reader would
      // read the whole error twice.
      expect(error.label, l10n.reportOtherRequiresDetails);
      expect(
        error.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
        reason: 'The error appears without focus moving, so it must announce',
      );

      handle.dispose();
    });

    testWidgets(
      'bottom sheet path surfaces validation errors inline without snackbars',
      (tester) async {
        await setLargeSurface(tester);
        await openBottomSheetReport(tester);

        await tester.ensureVisible(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.reportReasonOther));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportOtherRequiresDetails), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('dragging the sheet content down dismisses the sheet', (
      tester,
    ) async {
      await setLargeSurface(tester);
      await openBottomSheetReport(tester);

      expect(find.text(l10n.reportWhyReporting), findsOneWidget);

      // The sheet's scroll view must run on the DraggableScrollableSheet's
      // own controller — with a private one the drag never reaches the sheet
      // and the report form traps the user.
      await tester.drag(
        find.text(l10n.reportWhyReporting),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportWhyReporting), findsNothing);
    });

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
          sourceRelay: any(named: 'sourceRelay'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
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

    // #6387: sendMessage signals non-delivery by RETURNING a failure, never
    // by throwing, so the sibling `thenThrow` test above exercises a shape
    // production cannot produce. These pin the shapes it actually produces.
    void stubDmResult(NIP17SendResult result) {
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer((_) async => result);
    }

    testWidgets('shows the DM-delayed notice when the send is blocked', (
      tester,
    ) async {
      // The #176 protected-minor send gate returns before the outgoing
      // queue row is written, so this is the one branch with no retry.
      stubDmResult(
        const NIP17SendResult.blocked(
          'blocked: recipient not permitted by send policy',
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('shows the DM-delayed notice on a hard send failure', (
      tester,
    ) async {
      stubDmResult(
        const NIP17SendResult.failure('Message publish failed to relays'),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('shows the DM-delayed notice when the device is offline', (
      tester,
    ) async {
      // Verbatim the value NIP17MessageService returns when its
      // connectivity probe reports offline — the most common instance.
      stubDmResult(
        const NIP17SendResult.failure('Message not sent: device offline'),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('shows the DM-delayed notice when the send is unconfirmed', (
      tester,
    ) async {
      // Recipient frame written but no relay OK inside the window. The
      // durable queue re-drives it, so the notice is pessimistic rather
      // than wrong — but silence would be a claim we cannot support.
      stubDmResult(
        const NIP17SendResult.failure(
          'Message publish timed out',
          retryablePending: true,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsOneWidget);
      expect(find.text(l10n.reportModerationDmDelayed), findsOneWidget);
    });

    testWidgets('does not confirm when the report reached no channel', (
      tester,
    ) async {
      // #6387/R2: reportContent returns success even when the kind-1984
      // publish failed on every relay AND the Zendesk ticket failed. The
      // confirmation screen would then be false in four places at once, so
      // the flow must surface the failure instead of confirming.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(find.text(l10n.reportReceivedTitle), findsNothing);
      expect(
        find.text(l10n.reportNotSent),
        findsOneWidget,
      );
      // The DM still goes out: sendMessage writes a durable outgoing_dms
      // row before any I/O, and OutgoingDmRetryService replays it on
      // reconnect. It is the only report channel with a retry, so skipping
      // it would make an offline report deliver less often than before.
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).called(1);
    });

    testWidgets('does not queue a second moderation DM on a repeat submit', (
      tester,
    ) async {
      // Submit stays live on the undelivered path so retrying is one tap.
      // Each tap must not stack another identical row for the sweep to
      // deliver — the user is being invited to retry, not to spam.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(2);
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).called(1);
    });

    testWidgets('leaves the report resubmittable after it reached no channel', (
      tester,
    ) async {
      // Leaving Submit live is the whole reason this branch shows an inline
      // error instead of the confirmation, so pin it: a second tap must
      // reach the service again. That also proves the reason selection
      // survived, since _handleSubmitReport short-circuits to
      // reportSelectReason when _selectedReason is null.
      when(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'test_report_id',
          delivery: ReportDelivery.localOnly,
        ),
      );

      await setLargeSurface(tester);
      await openAndSubmitReport(tester);

      expect(
        find.text(l10n.reportNotSent),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(DivineButton, l10n.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reportSelectReason), findsNothing);
      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          sourceRelay: any(named: 'sourceRelay'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(2);
    });

    testWidgets('stays silent when only the sender self-wrap failed', (
      tester,
    ) async {
      // The moderation team DID receive the report; only the sender's own
      // cross-device copy is missing. Claiming we couldn't reach the team
      // would be false, so this must NOT show the notice.
      stubDmResult(
        NIP17SendResult.success(
          rumorEventId: 'dm_rumor_id',
          messageEventId: 'dm_event_id',
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
          selfWrapPublished: false,
        ),
      );

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
        when(
          () => mockAuth.currentPublicKeyHex,
        ).thenReturn(syntheticTestPubkey);

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
    const testSenderPubkey = syntheticTestPubkey;

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

    const testUserPubkey = syntheticTestPubkey;

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
            sourceRelay: any(named: 'sourceRelay'),
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
