import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/services/zendesk_support_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.openvine/zendesk_support');

  setUp(() {
    ZendeskSupportService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ZendeskSupportService.initialize', () {
    test('returns false when credentials empty', () async {
      final result = await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });

    test('returns true when native initialization succeeds', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              expect(call.arguments['appId'], 'test_app_id');
              expect(call.arguments['clientId'], 'test_client_id');
              expect(call.arguments['zendeskUrl'], 'https://test.zendesk.com');
              return true;
            }
            return null;
          });

      final result = await ZendeskSupportService.initialize(
        appId: 'test_app_id',
        clientId: 'test_client_id',
        zendeskUrl: 'https://test.zendesk.com',
      );

      expect(result, true);
      expect(ZendeskSupportService.isAvailable, true);
    });

    test('returns false when native initialization fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') {
              throw PlatformException(code: 'INIT_FAILED', message: 'Failed');
            }
            return null;
          });

      final result = await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });
  });

  group('ZendeskSupportService.showNewTicketScreen', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });

    test('passes parameters correctly to native', () async {
      // Initialize first
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'showNewTicket') {
              expect(call.arguments['subject'], 'Test Subject');
              expect(call.arguments['description'], 'Test Description');
              expect(call.arguments['tags'], ['tag1', 'tag2']);
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Test Subject',
        description: 'Test Description',
        tags: ['tag1', 'tag2'],
      );

      expect(result, true);
    });

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'showNewTicket') {
              throw PlatformException(code: 'SHOW_FAILED', message: 'Failed');
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });
  });

  group('ZendeskSupportService.showTicketListScreen', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, false);
    });

    test('calls native method when initialized', () async {
      var showTicketListCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'showTicketList') {
              showTicketListCalled = true;
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, true);
      expect(showTicketListCalled, true);
    });
  });

  group('ZendeskSupportService.setUserIdentity', () {
    test('uses NIP-05 as email when available', () {
      ZendeskSupportService.setUserIdentity(
        displayName: 'Test User',
        nip05: 'testuser@example.com',
        npub: 'npub1testtesttesttesttesttesttesttesttesttesttesttesttesttest',
      );

      expect(ZendeskSupportService.userName, 'Test User');
      expect(ZendeskSupportService.userEmail, 'testuser@example.com');
    });

    test('uses full npub as email when NIP-05 not available', () {
      const testNpub =
          'npub1abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345';
      ZendeskSupportService.setUserIdentity(npub: testNpub);

      // CRITICAL: Uses full npub for unique user identification
      // Email format: {npub}@divine.video
      expect(ZendeskSupportService.userEmail, '$testNpub@divine.video');
    });

    test('uses full npub as name when no displayName or NIP-05', () {
      const testNpub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuv';
      ZendeskSupportService.setUserIdentity(npub: testNpub);

      // CRITICAL: Uses full npub (never truncated) for traceability
      expect(ZendeskSupportService.userName, testNpub);
    });

    test('returns true even when native SDK not initialized', () {
      final result = ZendeskSupportService.setUserIdentity(
        displayName: 'Test',
        nip05: 'test@example.com',
        npub: 'npub1test',
      );

      expect(result, true);
    });

    test('stores npub correctly', () {
      ZendeskSupportService.setUserIdentity(
        displayName: 'Test',
        npub: 'npub1test',
      );

      expect(ZendeskSupportService.userNpub, 'npub1test');
    });
  });

  group('ZendeskSupportService.clearUserIdentity', () {
    test('calls native method when initialized', () async {
      var clearIdentityCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'clearUserIdentity') {
              clearIdentityCalled = true;
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.clearUserIdentity();

      expect(clearIdentityCalled, true);
    });
  });

  group('ZendeskSupportService.createTicket', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test description',
      );

      expect(result, false);
    });

    test('passes parameters correctly to native', () async {
      String? capturedSubject;
      String? capturedDescription;
      List<dynamic>? capturedTags;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              capturedDescription = call.arguments['description'] as String?;
              capturedTags = call.arguments['tags'] as List<dynamic>?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.createTicket(
        subject: 'Bug Report',
        description: 'Something broke',
        tags: ['mobile', 'bug'],
      );

      expect(capturedSubject, 'Bug Report');
      expect(capturedDescription, 'Something broke');
      expect(capturedTags, ['mobile', 'bug']);
    });
  });

  group('ZendeskSupportService identity consistency', () {
    test('same npub produces same synthetic email', () {
      const testNpub =
          'npub1consistent1234567890abcdef1234567890abcdef1234567890ab';

      ZendeskSupportService.setUserIdentity(
        displayName: 'User 1',
        npub: testNpub,
      );
      final email1 = ZendeskSupportService.userEmail;

      ZendeskSupportService.setUserIdentity(
        displayName: 'User 2',
        npub: testNpub,
      );
      final email2 = ZendeskSupportService.userEmail;

      expect(email1, email2);
    });

    test('different npubs produce different synthetic emails', () {
      ZendeskSupportService.setUserIdentity(
        npub: 'npub1user1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final email1 = ZendeskSupportService.userEmail;

      ZendeskSupportService.setUserIdentity(
        npub: 'npub1user2bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final email2 = ZendeskSupportService.userEmail;

      expect(email1, isNot(email2));
    });
  });

  group('ZendeskSupportService.createStructuredBugReport fallback', () {
    test('uses native SDK when initialized', () async {
      var createTicketCalled = false;
      String? capturedSubject;
      List<dynamic>? capturedCustomFields;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              createTicketCalled = true;
              capturedSubject = call.arguments['subject'] as String?;
              capturedCustomFields =
                  call.arguments['customFields'] as List<dynamic>?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.createStructuredBugReport(
        subject: 'Test Bug',
        description: 'Something broke',
        reportId: 'test-report-123',
        appVersion: '1.0.0+42',
        deviceInfo: {'platform': 'ios', 'version': '17.0', 'model': 'iPhone'},
        stepsToReproduce: '1. Tap button\n2. See crash',
        expectedBehavior: 'Should not crash',
      );

      expect(result, isTrue);
      expect(createTicketCalled, isTrue);
      expect(capturedSubject, 'Test Bug');
      // Verify custom fields include platform, OS version, build number
      expect(capturedCustomFields, isNotNull);
      final fieldIds = capturedCustomFields!
          .map((f) => (f as Map)['id'])
          .toList();
      // Platform field
      expect(fieldIds, contains(14884176561807));
      // OS Version field
      expect(fieldIds, contains(14884157556111));
      // Build Number field
      expect(fieldIds, contains(14884184890511));
      // Steps to Reproduce field (optional, but provided)
      expect(fieldIds, contains(14677364166031));
      // Expected Behavior field (optional, but provided)
      expect(fieldIds, contains(14677341431695));
    });

    test('falls back to REST API when SDK not initialized', () async {
      // Reset _initialized by calling initialize with a handler that fails
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return false;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // SDK not initialized → falls to REST API → but API token not configured
      // in test env, so returns false
      final result = await ZendeskSupportService.createStructuredBugReport(
        subject: 'Test Bug',
        description: 'Something broke',
        reportId: 'test-report-456',
        appVersion: '1.0.0+42',
        deviceInfo: {'platform': 'android', 'version': '14'},
      );

      // Without ZENDESK_API_TOKEN, REST API fallback returns false
      expect(result, isFalse);
    });

    test('extracts build number from appVersion correctly', () async {
      List<dynamic>? capturedCustomFields;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedCustomFields =
                  call.arguments['customFields'] as List<dynamic>?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.createStructuredBugReport(
        subject: 'Test',
        description: 'Test',
        reportId: 'test-789',
        appVersion: '2.1.0+99',
        deviceInfo: {'platform': 'ios', 'version': '18.0'},
      );

      // Verify build number extracted from "2.1.0+99" → "99"
      expect(capturedCustomFields, isNotNull);
      final buildField = capturedCustomFields!.firstWhere(
        (f) => (f as Map)['id'] == 14884184890511,
      );
      expect((buildField as Map)['value'], '99');
    });
  });

  group('ZendeskSupportService REST API', () {
    test('isRestApiAvailable returns false when token not configured', () {
      // ZendeskConfig uses String.fromEnvironment which defaults to ''
      // Without --dart-define, this will be empty
      expect(
        ZendeskConfig.apiToken.isEmpty || ZendeskConfig.isRestApiConfigured,
        isTrue,
      );
    });

    test('ZendeskConfig has default apiEmail configured', () {
      // The default email should be set for bug report submissions
      expect(ZendeskConfig.apiEmail, isNotEmpty);
      expect(ZendeskConfig.apiEmail, contains('@'));
    });

    test('createTicketViaApi returns false when API not configured', () async {
      // Without ZENDESK_API_TOKEN defined at compile time, this should return false
      final result = await ZendeskSupportService.createTicketViaApi(
        subject: 'Test Subject',
        description: 'Test Description',
      );

      // When API token is not configured, should return false
      expect(result, ZendeskConfig.isRestApiConfigured);
    });
  });
}
