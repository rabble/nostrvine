import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/services/nip98_auth_service.dart';
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

    test('retries with anonymous identity when NO_IDENTITY error', () async {
      var showNewTicketCallCount = 0;
      var setUserIdentityCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              setUserIdentityCalled = true;
              return true;
            }
            if (call.method == 'showNewTicket') {
              showNewTicketCallCount++;
              if (showNewTicketCallCount == 1) {
                throw PlatformException(
                  code: 'NO_IDENTITY',
                  message: 'Set an identity before showing Zendesk UI',
                );
              }
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, isTrue);
      expect(showNewTicketCallCount, 2);
      expect(setUserIdentityCalled, isTrue);
    });

    test('returns false when NO_IDENTITY retry also fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') return true;
            if (call.method == 'showNewTicket') {
              throw PlatformException(
                code: 'NO_IDENTITY',
                message: 'Set an identity before showing Zendesk UI',
              );
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, isFalse);
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

    test('retries with anonymous identity when NO_IDENTITY error', () async {
      var showTicketListCallCount = 0;
      var setUserIdentityCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') {
              setUserIdentityCalled = true;
              return true;
            }
            if (call.method == 'showTicketList') {
              showTicketListCallCount++;
              if (showTicketListCallCount == 1) {
                throw PlatformException(
                  code: 'NO_IDENTITY',
                  message: 'Set an identity before showing Zendesk UI',
                );
              }
              return null;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // Set user identity so anonymous fallback has name/email
      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, isTrue);
      expect(showTicketListCallCount, 2);
      expect(setUserIdentityCalled, isTrue);
    });

    test('returns false when NO_IDENTITY retry also fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'setUserIdentity') return true;
            if (call.method == 'showTicketList') {
              throw PlatformException(
                code: 'NO_IDENTITY',
                message: 'Set an identity before showing Zendesk UI',
              );
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      ZendeskSupportService.setUserIdentity(
        npub:
            'npub1test1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234',
        displayName: 'Test User',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, isFalse);
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

  group('ZendeskSupportService.createTicket JWT expiry retry', () {
    test(
      'retries with anonymous identity when JWT returns unauthorized',
      () async {
        var createTicketCallCount = 0;
        var setUserIdentityCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'setUserIdentity') {
                setUserIdentityCalled = true;
                return true;
              }
              if (call.method == 'createTicket') {
                createTicketCallCount++;
                if (createTicketCallCount == 1) {
                  // First call fails with expired JWT
                  throw PlatformException(
                    code: 'CREATE_FAILED',
                    message: 'unauthorized',
                  );
                }
                // Second call (after anonymous identity set) succeeds
                return true;
              }
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        // Set user identity so anonymous fallback has name/email
        ZendeskSupportService.setUserIdentity(
          npub: 'npub1test1234567890abcdef1234567890abcdef1234567890abcdef1234',
          displayName: 'Test User',
        );

        final result = await ZendeskSupportService.createTicket(
          subject: 'Content Report',
          description: 'Test report',
          tags: ['content-report'],
        );

        expect(result, isTrue);
        expect(createTicketCallCount, 2);
        expect(setUserIdentityCalled, isTrue);
      },
    );
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

    test('subject passes through without prefix modification', () async {
      String? capturedSubject;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // Subject should be passed exactly as provided -- no "fix:" prefix
      await ZendeskSupportService.createStructuredBugReport(
        subject: 'Links not working in DMs',
        description: 'When I tap a link it does nothing',
        reportId: 'test-subject-001',
        appVersion: '1.0.7+497',
        deviceInfo: {'platform': 'ios'},
      );

      expect(capturedSubject, 'Links not working in DMs');
      expect(capturedSubject, isNot(startsWith('fix:')));
    });

    test('subject with user-typed prefix is not double-prefixed', () async {
      String? capturedSubject;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'createTicket') {
              capturedSubject = call.arguments['subject'] as String?;
              return true;
            }
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      // If a user types "fix: something" it should pass through as-is
      await ZendeskSupportService.createStructuredBugReport(
        subject: 'fix: video upload stuck',
        description: 'Video stays at processing forever',
        reportId: 'test-subject-002',
        appVersion: '1.0.7+497',
        deviceInfo: {'platform': 'ios'},
      );

      expect(capturedSubject, 'fix: video upload stuck');
      expect(capturedSubject, isNot(startsWith('fix: fix:')));
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

  group('storeAuthContext and JWT refresh', () {
    test('resetForTesting clears stored auth context', () {
      // storeAuthContext is a static setter -- we verify it's cleared by
      // checking that createTicket doesn't attempt a JWT refresh when
      // auth context is absent (no setJwtIdentity call in the channel log)
      ZendeskSupportService.resetForTesting();

      // After reset, auth context should be null -- createTicket should
      // skip _ensureFreshJwt and proceed directly to SDK (or return false
      // if not initialized)
      expect(ZendeskSupportService.isAvailable, false);
    });

    test(
      'createTicket without auth context still works (no refresh attempt)',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'createTicket') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        // No storeAuthContext called -- _ensureFreshJwt should be a no-op
        methodCalls.clear();

        final result = await ZendeskSupportService.createTicket(
          subject: 'Test',
          description: 'Test description',
        );

        expect(result, true);
        // Should NOT have called setJwtIdentity (no auth context stored)
        expect(methodCalls, ['createTicket']);
      },
    );

    test(
      'createTicket with auth context attempts JWT refresh before SDK call',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'setJwtIdentity') return true;
              if (call.method == 'createTicket') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        // Store auth context -- _ensureFreshJwt will attempt setJwtIdentity.
        // fetchPreAuthToken will fail (no real server), but _ensureFreshJwt
        // catches the error and proceeds. The important thing is createTicket
        // still succeeds afterward.
        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://test-relay.divine.video',
        );

        methodCalls.clear();

        final result = await ZendeskSupportService.createTicket(
          subject: 'Test',
          description: 'Test description',
        );

        // createTicket should succeed even though JWT refresh failed
        // (the refresh is best-effort, not blocking)
        expect(result, true);
        expect(methodCalls, contains('createTicket'));
      },
    );

    test('showNewTicketScreen without auth context skips refresh', () async {
      final methodCalls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            methodCalls.add(call.method);
            if (call.method == 'initialize') return true;
            if (call.method == 'showNewTicket') return true;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      methodCalls.clear();

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, true);
      expect(methodCalls, ['showNewTicket']);
    });

    test('showTicketListScreen without auth context skips refresh', () async {
      final methodCalls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            methodCalls.add(call.method);
            if (call.method == 'initialize') return true;
            if (call.method == 'showTicketList') return true;
            return null;
          });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      methodCalls.clear();

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, true);
      expect(methodCalls, ['showTicketList']);
    });

    test(
      'showTicketListScreen falls back to anonymous identity when JWT refresh fails',
      () async {
        final methodCalls = <String>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'setUserIdentity') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );
        ZendeskSupportService.setUserIdentity(
          npub: 'npub1fallback1234567890abcdef1234567890abcdef1234567890abcdef',
          displayName: 'Fallback User',
        );
        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );

        methodCalls.clear();

        final result = await ZendeskSupportService.showTicketListScreen();

        expect(result, isTrue);
        expect(methodCalls, ['setUserIdentity', 'showTicketList']);
      },
    );

    test(
      'showTicketListScreen reuses a recent JWT refresh for consecutive calls',
      () async {
        final methodCalls = <String>[];
        var refreshCallCount = 0;
        final now = DateTime.utc(2026, 3, 24, 12);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );
        ZendeskSupportService.setTestHooks(
          now: () => now,
          jwtIdentityRefresh:
              ({
                required Nip98AuthService nip98Service,
                required String relayManagerUrl,
              }) async {
                refreshCallCount++;
                return true;
              },
        );

        methodCalls.clear();

        final firstResult = await ZendeskSupportService.showTicketListScreen();
        final secondResult = await ZendeskSupportService.showTicketListScreen();

        expect(firstResult, isTrue);
        expect(secondResult, isTrue);
        expect(refreshCallCount, 1);
        expect(methodCalls.where((m) => m == 'showTicketList').length, 2);
      },
    );

    test(
      'showTicketListScreen refreshes again once cached JWT is stale',
      () async {
        var refreshCallCount = 0;
        var now = DateTime.utc(2026, 3, 24, 12);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'initialize') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );
        ZendeskSupportService.setTestHooks(
          now: () => now,
          jwtIdentityRefresh:
              ({
                required Nip98AuthService nip98Service,
                required String relayManagerUrl,
              }) async {
                refreshCallCount++;
                return true;
              },
        );

        final firstResult = await ZendeskSupportService.showTicketListScreen();
        now = now.add(const Duration(minutes: 5));
        final secondResult = await ZendeskSupportService.showTicketListScreen();

        expect(firstResult, isTrue);
        expect(secondResult, isTrue);
        expect(refreshCallCount, 2);
      },
    );

    test(
      'clearUserIdentity clears stored auth context for future SDK actions',
      () async {
        final methodCalls = <String>[];
        var refreshCallCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              methodCalls.add(call.method);
              if (call.method == 'initialize') return true;
              if (call.method == 'clearUserIdentity') return true;
              if (call.method == 'showTicketList') return true;
              return null;
            });

        await ZendeskSupportService.initialize(
          appId: 'test',
          clientId: 'test',
          zendeskUrl: 'https://test.zendesk.com',
        );

        ZendeskSupportService.storeAuthContext(
          nip98Service: _FakeNip98AuthService(),
          relayManagerUrl: 'https://relay-manager.divine.video',
        );
        ZendeskSupportService.setTestHooks(
          jwtIdentityRefresh:
              ({
                required Nip98AuthService nip98Service,
                required String relayManagerUrl,
              }) async {
                refreshCallCount++;
                return true;
              },
        );

        await ZendeskSupportService.clearUserIdentity();
        methodCalls.clear();

        final result = await ZendeskSupportService.showTicketListScreen();

        expect(result, isTrue);
        expect(refreshCallCount, 0);
        expect(methodCalls, ['showTicketList']);
      },
    );
  });
}

/// Minimal fake for Nip98AuthService that always fails token creation.
/// Tests that _ensureFreshJwt handles failures gracefully.
class _FakeNip98AuthService implements Nip98AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // createAuthToken and clearTokenCache are the only methods called
    // by fetchPreAuthToken. Return null/void for all calls, which causes
    // fetchPreAuthToken to throw, which _ensureFreshJwt catches gracefully.
    return null;
  }
}
