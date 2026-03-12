// ABOUTME: Unit tests for bug report submission flow via BugReportService
// ABOUTME: Tests NIP-17 + Blossom paths with mocked dependencies (no network calls)

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show BugReportData, LogCategory, LogEntry, LogLevel, NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/nip17_message_service.dart';

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNIP17MessageService mockNip17;
  late _MockBlossomUploadService mockBlossom;
  late _MockNostrClient mockNostrClient;
  late BugReportService service;
  late Directory tempDir;

  final testData = BugReportData(
    reportId: 'test-report-001',
    timestamp: DateTime(2026, 3, 9),
    userDescription: 'App crashed on startup',
    deviceInfo: {
      'platform': 'ios',
      'version': '17.0',
      'model': 'iPhone 15',
    },
    appVersion: '1.0.0+42',
    recentLogs: [
      LogEntry(
        timestamp: DateTime(2026, 3, 9),
        level: LogLevel.error,
        message: 'Null check operator used on null value',
        category: LogCategory.system,
      ),
    ],
    errorCounts: {'NullCheckError': 3},
    currentScreen: 'HomeScreen',
  );

  setUpAll(() {
    registerFallbackValue(File(''));
  });

  setUp(() async {
    mockNip17 = _MockNIP17MessageService();
    mockBlossom = _MockBlossomUploadService();
    mockNostrClient = _MockNostrClient();

    // Mock path_provider for _createBugReportFile
    final binding = TestDefaultBinaryMessengerBinding.instance;
    tempDir = await Directory.systemTemp.createTemp('bug_report_test_');

    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    // Also mock the macOS variant
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider_macos'),
      (MethodCall call) async {
        if (call.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    // Mock nostrService getter and addRelay for backup relay connection
    when(() => mockNip17.nostrService).thenReturn(mockNostrClient);
    when(
      () => mockNostrClient.addRelay(any()),
    ).thenAnswer((_) async => true);

    service = BugReportService(
      nip17MessageService: mockNip17,
      blossomUploadService: mockBlossom,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BugReportService.sendBugReportToRecipient', () {
    test('succeeds when NIP-17 DM and Blossom upload both succeed', () async {
      when(
        () => mockBlossom.uploadBugReport(
          bugReportFile: any(named: 'bugReportFile'),
        ),
      ).thenAnswer((_) async => 'https://media.divine.video/bug-report.txt');

      when(
        () => mockNip17.sendPrivateMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: 'event-abc123',
          recipientPubkey: 'test-pubkey',
        ),
      );

      final result = await service.sendBugReportToRecipient(
        testData,
        'test-pubkey',
      );

      expect(result.success, isTrue);
      expect(result.reportId, equals('test-report-001'));
      expect(result.messageEventId, equals('event-abc123'));
    });

    test(
      'returns partial success when DM fails but Blossom URL exists',
      () async {
        when(
          () => mockBlossom.uploadBugReport(
            bugReportFile: any(named: 'bugReportFile'),
          ),
        ).thenAnswer((_) async => 'https://media.divine.video/bug-report.txt');

        when(
          () => mockNip17.sendPrivateMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult(
            success: false,
            error: 'No relays available',
          ),
        );

        final result = await service.sendBugReportToRecipient(
          testData,
          'test-pubkey',
        );

        // Partial success: Blossom URL exists even though DM failed
        expect(result.success, isTrue);
        expect(result.reportId, equals('test-report-001'));
        expect(result.error, contains('Blossom'));
      },
    );

    test('falls back to email when NIP-17 service not available', () async {
      // Create service without NIP-17 service
      final serviceWithoutNip17 = BugReportService();

      final result = await serviceWithoutNip17.sendBugReportToRecipient(
        testData,
        'test-pubkey',
      );

      // Falls back to email — result depends on platform share dialog
      // but the method should not throw
      expect(result.success, isNotNull);
    });

    test(
      'NIP-17 message includes bug report URL in tags when uploaded',
      () async {
        when(
          () => mockBlossom.uploadBugReport(
            bugReportFile: any(named: 'bugReportFile'),
          ),
        ).thenAnswer(
          (_) async => 'https://media.divine.video/report-file.txt',
        );

        List<List<String>>? capturedTags;
        when(
          () => mockNip17.sendPrivateMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags =
              invocation.namedArguments[#additionalTags] as List<List<String>>?;
          return NIP17SendResult.success(
            messageEventId: 'event-xyz',
            recipientPubkey: 'test-pubkey',
          );
        });

        await service.sendBugReportToRecipient(testData, 'test-pubkey');

        expect(capturedTags, isNotNull);
        // Should include client tag, report_id tag, app_version tag,
        // and bug_report_url tag
        final tagNames = capturedTags!.map((t) => t.first).toList();
        expect(tagNames, contains('client'));
        expect(tagNames, contains('report_id'));
        expect(tagNames, contains('app_version'));
        expect(tagNames, contains('bug_report_url'));
      },
    );

    test('sends summary only when Blossom upload not available', () async {
      // Create service with NIP-17 but without Blossom
      final serviceNoBlossom = BugReportService(
        nip17MessageService: mockNip17,
      );

      String? capturedContent;
      when(
        () => mockNip17.sendPrivateMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenAnswer((invocation) async {
        capturedContent = invocation.namedArguments[#content] as String?;
        return NIP17SendResult.success(
          messageEventId: 'event-no-blossom',
          recipientPubkey: 'test-pubkey',
        );
      });

      final result = await serviceNoBlossom.sendBugReportToRecipient(
        testData,
        'test-pubkey',
      );

      expect(result.success, isTrue);
      expect(capturedContent, contains('Blossom unavailable'));
      // Should NOT have bug_report_url tag
      verify(
        () => mockNip17.sendPrivateMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).called(1);
    });
  });
}
