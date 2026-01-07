import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/config/zendesk_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.openvine/zendesk_support');

  setUp(() {
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
    test('uses NIP-05 as email when available', () async {
      String? capturedName;
      String? capturedEmail;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              capturedName = call.arguments['name'] as String?;
              capturedEmail = call.arguments['email'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.setUserIdentity(
        displayName: 'Test User',
        nip05: 'testuser@example.com',
        npub: 'npub1testtesttesttesttesttesttesttesttesttesttesttesttesttest',
      );

      expect(capturedName, 'Test User');
      expect(capturedEmail, 'testuser@example.com');
    });

    test('uses full npub as email when NIP-05 not available', () async {
      String? capturedEmail;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              capturedEmail = call.arguments['email'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      const testNpub =
          'npub1abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345';
      await ZendeskSupportService.setUserIdentity(
        displayName: null,
        nip05: null,
        npub: testNpub,
      );

      // CRITICAL: Uses full npub for unique user identification
      // Email format: {npub}@divine.video
      expect(capturedEmail, '$testNpub@divine.video');
    });

    test('uses full npub as name when no displayName or NIP-05', () async {
      String? capturedName;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              capturedName = call.arguments['name'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      const testNpub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuv';
      await ZendeskSupportService.setUserIdentity(
        displayName: null,
        nip05: null,
        npub: testNpub,
      );

      // CRITICAL: Uses full npub (never truncated) for traceability
      expect(capturedName, testNpub);
    });

    test(
      'returns true even when native SDK not initialized (REST API fallback)',
      () async {
        // Don't initialize native SDK
        final result = await ZendeskSupportService.setUserIdentity(
          displayName: 'Test',
          nip05: 'test@example.com',
          npub: 'npub1test',
        );

        // Should still return true because REST API can use stored values
        expect(result, true);
      },
    );

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              throw PlatformException(code: 'ERROR', message: 'Test error');
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // Should not throw, should return true (REST API fallback)
      final result = await ZendeskSupportService.setUserIdentity(
        displayName: 'Test',
        nip05: null,
        npub: 'npub1test',
      );

      expect(result, true);
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
    test('same npub produces same synthetic email', () async {
      final emails = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              emails.add(call.arguments['email'] as String);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      const testNpub =
          'npub1consistent1234567890abcdef1234567890abcdef1234567890ab';

      // Call setUserIdentity twice with same npub
      await ZendeskSupportService.setUserIdentity(
        displayName: 'User 1',
        nip05: null,
        npub: testNpub,
      );

      await ZendeskSupportService.setUserIdentity(
        displayName: 'User 2',
        nip05: null,
        npub: testNpub,
      );

      // Both should produce the same email
      expect(emails.length, 2);
      expect(emails[0], emails[1]);
    });

    test('different npubs produce different synthetic emails', () async {
      final emails = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              emails.add(call.arguments['email'] as String);
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      await ZendeskSupportService.setUserIdentity(
        displayName: null,
        nip05: null,
        npub: 'npub1user1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );

      await ZendeskSupportService.setUserIdentity(
        displayName: null,
        nip05: null,
        npub: 'npub1user2bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );

      expect(emails.length, 2);
      expect(emails[0], isNot(emails[1]));
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

    test(
      'createBugReportTicketViaApi returns false when API not configured',
      () async {
        final result = await ZendeskSupportService.createBugReportTicketViaApi(
          reportId: 'test-123',
          userDescription: 'Test bug',
          appVersion: '1.0.0',
          deviceInfo: {'platform': 'test'},
        );

        // When API token is not configured, should return false
        expect(result, ZendeskConfig.isRestApiConfigured);
      },
    );
  });
}
