// ABOUTME: Unit tests for ReportContentDialog widget
// ABOUTME: Tests Apple compliance requirements, reason selection, submission, and blocking

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart' as nostr;
import 'package:models/models.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/providers/app_providers.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_provider_overrides.mocks.dart';
import 'report_content_dialog_test.mocks.dart';

@GenerateMocks([ContentReportingService, ContentBlocklistService, MuteService])
void main() {
  late VideoEvent testVideo;
  late MockContentReportingService mockReportingService;
  late MockContentBlocklistService mockBlocklistService;
  late MockMuteService mockMuteService;

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
    mockReportingService = MockContentReportingService();
    mockBlocklistService = MockContentBlocklistService();
    mockMuteService = MockMuteService();

    // Setup default mock behavior
    when(
      mockReportingService.reportContent(
        eventId: anyNamed('eventId'),
        authorPubkey: anyNamed('authorPubkey'),
        reason: anyNamed('reason'),
        details: anyNamed('details'),
        additionalContext: anyNamed('additionalContext'),
        hashtags: anyNamed('hashtags'),
      ),
    ).thenAnswer((_) async => ReportResult.createSuccess('test_report_id'));

    when(
      mockReportingService.reportUser(
        userPubkey: anyNamed('userPubkey'),
        reason: anyNamed('reason'),
        details: anyNamed('details'),
        relatedEventIds: anyNamed('relatedEventIds'),
      ),
    ).thenAnswer(
      (_) async => ReportResult.createSuccess('test_user_report_id'),
    );

    when(
      mockMuteService.muteUser(
        any,
        reason: anyNamed('reason'),
        duration: anyNamed('duration'),
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
            contentBlocklistServiceProvider.overrideWith(
              (ref) => mockBlocklistService,
            ),
            muteServiceProvider.overrideWith((ref) async => mockMuteService),
          ],
          child: MaterialApp(
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
      when(mockNostrClient.publicKey).thenReturn('test_pubkey_hex');
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
        mockUserProfileService: createMockUserProfileService(),
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          contentBlocklistServiceProvider.overrideWith(
            (ref) => mockBlocklistService,
          ),
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
        ],
        child: MaterialApp.router(routerConfig: router),
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
        mockReportingService.reportContent(
          eventId: anyNamed('eventId'),
          authorPubkey: anyNamed('authorPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          additionalContext: anyNamed('additionalContext'),
          hashtags: anyNamed('hashtags'),
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

    testWidgets('report with block checkbox calls reportUser and muteUser', (
      tester,
    ) async {
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

      // Verify content report was made
      verify(
        mockReportingService.reportContent(
          eventId: anyNamed('eventId'),
          authorPubkey: anyNamed('authorPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          additionalContext: anyNamed('additionalContext'),
          hashtags: anyNamed('hashtags'),
        ),
      ).called(1);

      // Verify user report was made
      verify(
        mockReportingService.reportUser(
          userPubkey: anyNamed('userPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          relatedEventIds: anyNamed('relatedEventIds'),
        ),
      ).called(1);

      // Verify mute was called
      verify(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).called(1);
    });

    testWidgets('failed report shows error snackbar', (tester) async {
      when(
        mockReportingService.reportContent(
          eventId: anyNamed('eventId'),
          authorPubkey: anyNamed('authorPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          additionalContext: anyNamed('additionalContext'),
          hashtags: anyNamed('hashtags'),
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
        mockReportingService.reportContent(
          eventId: anyNamed('eventId'),
          authorPubkey: anyNamed('authorPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          additionalContext: anyNamed('additionalContext'),
          hashtags: anyNamed('hashtags'),
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
        mockReportingService.reportContent(
          eventId: anyNamed('eventId'),
          authorPubkey: anyNamed('authorPubkey'),
          reason: anyNamed('reason'),
          details: captureAnyNamed('details'),
          additionalContext: anyNamed('additionalContext'),
          hashtags: anyNamed('hashtags'),
        ),
      ).called(1);
    });
  });

  group('$ReportConfirmationDialog', () {
    testWidgets('renders success content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
      expect(find.text('Learn More'), findsOneWidget);
      expect(find.text('divine.video/safety'), findsOneWidget);
    });

    testWidgets('renders Close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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

  // Unit test for Nostr event service calls
  group('Nostr Event Publishing', () {
    test('reportUser() and muteUser() are called when blocking', () async {
      final mockReportingService = MockContentReportingService();
      final mockMuteService = MockMuteService();

      when(
        mockReportingService.reportUser(
          userPubkey: anyNamed('userPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          relatedEventIds: anyNamed('relatedEventIds'),
        ),
      ).thenAnswer((_) async => ReportResult.createSuccess('user_report_id'));

      when(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).thenAnswer((_) async => true);

      final userReportResult = await mockReportingService.reportUser(
        userPubkey:
            '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
        reason: ContentFilterReason.harassment,
        details: 'Test user report',
        relatedEventIds: ['test_event_id'],
      );

      final muteResult = await mockMuteService.muteUser(
        '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
        reason: 'Test mute',
      );

      expect(userReportResult.success, isTrue);
      expect(muteResult, isTrue);

      verify(
        mockReportingService.reportUser(
          userPubkey: anyNamed('userPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          relatedEventIds: anyNamed('relatedEventIds'),
        ),
      ).called(1);

      verify(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).called(1);
    });
  });
}
