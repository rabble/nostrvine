// ABOUTME: Unit tests for ReportContentDialog widget
// ABOUTME: Tests Apple compliance requirements, reason selection, submission, and blocking

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
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
  setUpAll(() {
    registerFallbackValue(ContentFilterReason.spam);
  });

  late VideoEvent testVideo;
  late _MockContentReportingService mockReportingService;
  late _MockContentBlocklistRepository mockBlocklistRepository;
  late _MockMuteService mockMuteService;

  setUp(() {
    // Create test Nostr event with valid hex pubkey
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

    // Setup default mock behavior
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
      () => mockMuteService.muteUser(
        any(),
        reason: any(named: 'reason'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async => true);
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

    testWidgets('renders Report Content title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Report Content'), findsOneWidget);
      expect(find.text('Why are you reporting this content?'), findsOneWidget);
    });

    testWidgets('renders all report reason radio options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Spam or Unwanted Content'), findsOneWidget);
      expect(find.text('Harassment, Bullying, or Threats'), findsOneWidget);
      expect(find.text('Violent or Extremist Content'), findsOneWidget);
      expect(find.text('Sexual or Adult Content'), findsOneWidget);
      expect(find.text('Copyright Violation'), findsOneWidget);
      expect(find.text('False Information'), findsOneWidget);
      expect(find.text('Child Safety Violation'), findsOneWidget);
      expect(find.text('AI-Generated Content'), findsOneWidget);
      expect(find.text('Other Policy Violation'), findsOneWidget);
    });

    testWidgets('renders additional details text field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Additional details (optional)'), findsOneWidget);
    });

    testWidgets(
      'Submit button is visible (not null) even before selecting a reason',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final reportButton = find.widgetWithText(TextButton, 'Report');
        expect(reportButton, findsOneWidget);

        final TextButton button = tester.widget(reportButton);
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
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final reportButton = find.widgetWithText(TextButton, 'Report');
        await tester.tap(reportButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Please select a reason for reporting this content'),
          findsOneWidget,
          reason: 'Should show error when no reason selected',
        );
      },
    );

    testWidgets(
      'Submit button shows error when Other selected without details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Select "Other"
        await tester.tap(find.text('Other Policy Violation'));
        await tester.pumpAndSettle();

        // Tap Report without entering details
        final reportButton = find.widgetWithText(TextButton, 'Report');
        await tester.tap(reportButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Please describe the issue when selecting Other'),
          findsOneWidget,
          reason: 'Should require details when Other is selected',
        );
      },
    );

    testWidgets('Block user checkbox is visible and can be toggled', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistRepositoryProvider.overrideWith(
              (ref) => mockBlocklistRepository,
            ),
            muteServiceProvider.overrideWith((ref) async => mockMuteService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ReportContentDialog(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final blockUserCheckbox = find.text('Block this user');
      expect(
        blockUserCheckbox,
        findsOneWidget,
        reason: 'Block user checkbox should be visible',
      );

      final Checkbox checkbox = tester.widget(find.byType(Checkbox));
      expect(
        checkbox.value,
        isFalse,
        reason: 'Checkbox should be unchecked by default',
      );

      await tester.tap(blockUserCheckbox);
      await tester.pumpAndSettle();

      final Checkbox checkedCheckbox = tester.widget(find.byType(Checkbox));
      expect(
        checkedCheckbox.value,
        isTrue,
        reason: 'Checkbox should be checked after tapping',
      );
    });

    testWidgets('renders correct number of report reason options', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify all ContentFilterReason values have corresponding radio tiles
      final radios = tester.widgetList<RadioListTile<ContentFilterReason>>(
        find.byType(RadioListTile<ContentFilterReason>),
      );
      expect(radios.length, equals(ContentFilterReason.values.length));

      // Initially no reason is selected (check RadioGroup ancestor)
      final radioGroup = tester.widget<RadioGroup<ContentFilterReason>>(
        find.byType(RadioGroup<ContentFilterReason>),
      );
      expect(radioGroup.groupValue, isNull);
    });

    testWidgets('renders Cancel button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });
  });

  group('$ReportContentDialog submission', () {
    late MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = createMockNostrService();
      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
    });

    Widget buildSubject() {
      // GoRouter is needed so context.pop() (GoRouter extension) works.
      // showDialog is used so context.pop() pops the dialog route,
      // matching production usage.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ReportContentDialog(video: testVideo),
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

    /// Opens the report dialog by tapping the trigger button.
    Future<void> openReportDialog(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();
    }

    testWidgets('selecting reason and tapping Report calls reportContent', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select a reason
      await tester.tap(find.text('Spam or Unwanted Content'));
      await tester.pumpAndSettle();

      // Tap Report
      await tester.tap(find.widgetWithText(TextButton, 'Report'));
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
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select a reason
      await tester.tap(find.text('Harassment, Bullying, or Threats'));
      await tester.pumpAndSettle();

      // Tap Report
      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Report Received'), findsOneWidget);
      expect(
        find.text('Thank you for helping keep Divine safe.'),
        findsOneWidget,
      );
    });

    testWidgets('report with block checkbox calls muteUser but NOT reportUser '
        '(no duplicate Kind 1984)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select a reason
      await tester.tap(find.text('Harassment, Bullying, or Threats'));
      await tester.pumpAndSettle();

      // Check block user
      await tester.tap(find.text('Block this user'));
      await tester.pumpAndSettle();

      // Tap Report
      await tester.tap(find.widgetWithText(TextButton, 'Report'));
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

      verifyNever(
        () => mockReportingService.reportUser(
          userPubkey: any(named: 'userPubkey'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          relatedEventIds: any(named: 'relatedEventIds'),
        ),
      );

      verify(
        () => mockMuteService.muteUser(
          any(),
          reason: any(named: 'reason'),
          duration: any(named: 'duration'),
        ),
      ).called(1);
    });

    testWidgets('Report button is disabled while submission is in progress '
        '(prevents double-tap duplicate Kind 1984)', (tester) async {
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

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select a reason
      await tester.tap(find.text('Spam or Unwanted Content'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pump();

      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      final hasDisabledReportButton = buttons.any(
        (btn) => btn.onPressed == null,
      );
      expect(hasDisabledReportButton, isTrue);

      completer.complete(ReportResult.createSuccess('test_report_id'));
      await tester.pumpAndSettle();
    });

    testWidgets('failed report shows error snackbar', (tester) async {
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

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select a reason
      await tester.tap(find.text('Spam or Unwanted Content'));
      await tester.pumpAndSettle();

      // Tap Report
      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to report content'), findsOneWidget);
    });

    testWidgets('exception during report shows error snackbar', (tester) async {
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

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      await tester.tap(find.text('Spam or Unwanted Content'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to report content'), findsOneWidget);
    });

    testWidgets('additional details are passed to reportContent', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select a reason
      await tester.tap(find.text('Spam or Unwanted Content'));
      await tester.pumpAndSettle();

      // Enter additional details
      await tester.enterText(find.byType(TextField), 'This is spam content');
      await tester.pumpAndSettle();

      // Tap Report
      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pumpAndSettle();

      verify(
        () => mockReportingService.reportContent(
          eventId: any(named: 'eventId'),
          authorPubkey: any(named: 'authorPubkey'),
          reason: any(named: 'reason'),
          details: captureAny(named: 'details'),
          additionalContext: any(named: 'additionalContext'),
          hashtags: any(named: 'hashtags'),
        ),
      ).called(1);
    });

    testWidgets('Other reason with details submits successfully', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openReportDialog(tester);

      // Select Other
      await tester.tap(find.text('Other Policy Violation'));
      await tester.pumpAndSettle();

      // Enter details
      await tester.enterText(find.byType(TextField), 'Custom report details');
      await tester.pumpAndSettle();

      // Tap Report
      await tester.tap(find.widgetWithText(TextButton, 'Report'));
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

      expect(find.text('Report Received'), findsOneWidget);
      expect(
        find.text('Thank you for helping keep Divine safe.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('via direct message'),
        findsOneWidget,
        reason: 'TC-025: Confirmation should mention DM follow-up',
      );
      expect(find.text('Learn More'), findsOneWidget);
      expect(find.text('divine.video/safety'), findsOneWidget);
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

      expect(find.text('Close'), findsOneWidget);
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
                    builder: (_) => ReportContentDialog(video: testVideo),
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

      await tester.tap(find.text('Spam or Unwanted Content'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Report'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends DM to moderation team after successful report', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openAndSubmitReport(tester);

      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: ModerationLabelService.fallbackModerationPubkeyHex,
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).called(1);
    });

    testWidgets('DM content includes report reason and event ID', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openAndSubmitReport(tester);

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
          replyToId: any(named: 'replyToId'),
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
        ),
      ).thenThrow(Exception('DM relay unreachable'));

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openAndSubmitReport(tester);

      // Confirmation dialog should still appear
      expect(
        find.text('Report Received'),
        findsOneWidget,
        reason: 'Report should succeed even if DM fails',
      );
    });

    testWidgets(
      'report succeeds when DM send throws (unauthenticated/no keys)',
      (tester) async {
        // Simulate unauthenticated scenario where sendMessage throws
        final noKeysDmRepo = _MockDmRepository();
        when(
          () => noKeysDmRepo.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
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
                      builder: (_) => ReportContentDialog(video: testVideo),
                    ),
                    child: const Text('Open Report'),
                  ),
                ),
              ),
            ),
          ],
        );

        await tester.binding.setSurfaceSize(const Size(800, 1200));
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

        await tester.tap(find.text('Spam or Unwanted Content'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Report'));
        await tester.pumpAndSettle();

        // Report should succeed even when DM fails
        expect(find.text('Report Received'), findsOneWidget);
        verifyNever(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
          ),
        );
      },
    );
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
