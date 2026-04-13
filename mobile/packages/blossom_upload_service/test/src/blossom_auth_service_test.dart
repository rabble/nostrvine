// ABOUTME: Tests for Blossom BUD-01 authentication service (kind 24242)
// ABOUTME: Validates creation of signed auth events for age-restricted content
// access

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

void main() {
  late _MockAuthProvider mockAuthProvider;
  late BlossomAuthService blossomAuthService;

  setUp(() {
    mockAuthProvider = _MockAuthProvider();
    blossomAuthService = BlossomAuthService(authProvider: mockAuthProvider);
  });

  tearDown(() {
    blossomAuthService.dispose();
  });

  group('BlossomAuthService - GET request auth', () {
    test(
      'createGetAuthHeader returns null when user not authenticated',
      () async {
        // Arrange
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);

        // Act
        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://blossom.example.com',
        );

        // Assert
        expect(result, isNull);
      },
    );

    test(
      'createGetAuthHeader creates kind 24242 event with correct tags',
      () async {
        // Arrange
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

        const signedEvent = BlossomSignedEvent(
          json: {
            'id': 'event123',
            'kind': 24242,
            'pubkey': 'pubkey123',
            'created_at': 1234567890,
            'content': 'Get blob from Blossom server',
            'tags': [
              ['t', 'get'],
              ['x', 'abc123'],
              ['expiration', '1234570000'],
            ],
            'sig': 'signature123',
          },
        );

        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: 24242,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => signedEvent);

        // Act
        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://blossom.example.com',
        );

        // Assert
        expect(result, isNotNull);
        expect(result, startsWith('Nostr '));

        // Verify correct event creation
        final captured = verify(
          () => mockAuthProvider.createAndSignEvent(
            kind: 24242,
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        expect(captured[0], contains('Get blob'));
        final tags = captured[1] as List<List<String>>;
        expect(tags.any((tag) => tag[0] == 't' && tag[1] == 'get'), isTrue);
        expect(tags.any((tag) => tag[0] == 'x' && tag[1] == 'abc123'), isTrue);
        expect(tags.any((tag) => tag[0] == 'expiration'), isTrue);
      },
    );

    test(
      'createGetAuthHeader includes server tag when serverUrl provided',
      () async {
        // Arrange
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

        const signedEvent = BlossomSignedEvent(
          json: {
            'id': 'event123',
            'kind': 24242,
            'pubkey': 'pubkey123',
            'created_at': 1234567890,
            'content': 'Get blob from Blossom server',
            'tags': [
              ['t', 'get'],
              ['x', 'abc123'],
              ['server', 'https://blossom.example.com'],
            ],
            'sig': 'signature123',
          },
        );

        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => signedEvent);

        // Act
        await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://blossom.example.com',
        );

        // Assert
        final captured = verify(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        expect(
          tags.any(
            (tag) =>
                tag[0] == 'server' && tag[1] == 'https://blossom.example.com',
          ),
          isTrue,
        );
      },
    );

    test('createGetAuthHeader caches tokens to avoid re-signing', () async {
      // Arrange
      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

      const signedEvent = BlossomSignedEvent(
        json: {
          'id': 'event123',
          'kind': 24242,
          'tags': [
            ['t', 'get'],
            ['x', 'abc123'],
          ],
        },
      );

      when(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);

      // Act
      final result1 = await blossomAuthService.createGetAuthHeader(
        sha256Hash: 'abc123',
      );
      final result2 = await blossomAuthService.createGetAuthHeader(
        sha256Hash: 'abc123',
      );

      // Assert
      expect(result1, equals(result2));
      verify(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1); // Only called once due to caching
    });

    test('createGetAuthHeader sets expiration 1 hour in future', () async {
      // Arrange
      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

      const signedEvent = BlossomSignedEvent(
        json: {
          'id': 'event123',
          'kind': 24242,
          'tags': [
            ['t', 'get'],
            ['x', 'abc123'],
          ],
        },
      );

      when(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);

      // Act
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      // Assert
      final captured = verify(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured[0] as List<List<String>>;
      final expirationTag = tags.firstWhere((tag) => tag[0] == 'expiration');
      final expirationTimestamp = int.parse(expirationTag[1]);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final oneHourFromNow = now + 3600;

      // Allow 5 second tolerance for test execution time
      expect(expirationTimestamp, greaterThanOrEqualTo(now + 3595));
      expect(expirationTimestamp, lessThanOrEqualTo(oneHourFromNow + 5));
    });
  });

  group('BlossomAuthService - error handling', () {
    test(
      'createGetAuthHeader returns null when signing fails',
      () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
        );

        expect(result, isNull);
      },
    );

    test(
      'createGetAuthHeader returns null when signing throws',
      () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenThrow(Exception('signing error'));

        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
        );

        expect(result, isNull);
      },
    );

    test(
      'createGetAuthHeader handles short hash in logging',
      () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => const BlossomSignedEvent(
            json: {'id': 'e1', 'kind': 24242, 'tags': <List<String>>[]},
          ),
        );

        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'short',
        );

        expect(result, isNotNull);
        expect(result, startsWith('Nostr '));
      },
    );

    test(
      'createGetAuthHeader omits server tag when serverUrl is empty',
      () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => const BlossomSignedEvent(
            json: {'id': 'e1', 'kind': 24242, 'tags': <List<String>>[]},
          ),
        );

        await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123def456',
          serverUrl: '',
        );

        final captured = verify(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        expect(tags.any((tag) => tag[0] == 'server'), isFalse);
      },
    );
  });

  group('BlossomAuthService - cache management', () {
    test('clearCache removes all cached tokens', () async {
      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

      const signedEvent = BlossomSignedEvent(
        json: {
          'id': 'event123',
          'kind': 24242,
          'tags': [
            ['t', 'get'],
          ],
        },
      );

      when(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);

      // Create a cached token
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      // Clear the cache
      blossomAuthService.clearCache();

      // Second call should create new token (not use cache)
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      verify(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(2);
    });

    test('cacheStats returns correct statistics', () async {
      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

      const signedEvent = BlossomSignedEvent(
        json: {
          'id': 'event123',
          'kind': 24242,
          'tags': [
            ['t', 'get'],
          ],
        },
      );

      when(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);

      // Cache a token
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      final stats = blossomAuthService.cacheStats;

      expect(stats['total_cached'], equals(1));
      expect(stats['valid_headers'], equals(1));
      expect(stats['expired_headers'], equals(0));
      expect(stats['is_authenticated'], isTrue);
      expect(stats['cleanup_interval_minutes'], equals(15));
      expect(stats['token_validity_hours'], equals(1));
    });

    test('canCreateHeaders returns authentication status', () {
      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
      expect(blossomAuthService.canCreateHeaders, isTrue);

      when(() => mockAuthProvider.isAuthenticated).thenReturn(false);
      expect(blossomAuthService.canCreateHeaders, isFalse);
    });
  });
}
