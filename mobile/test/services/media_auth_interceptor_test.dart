// ABOUTME: Tests for media authentication interceptor handling 401 errors
// ABOUTME: Validates privacy-first auth flow for age-restricted Blossom content

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';

class MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class MockMediaViewerAuthService extends Mock
    implements MediaViewerAuthService {}

class MockBuildContext extends Mock implements BuildContext {}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockAgeVerificationService mockAgeVerificationService;
  late MockMediaViewerAuthService mockMediaViewerAuthService;
  late MediaAuthInterceptor interceptor;
  late MockBuildContext mockContext;

  setUpAll(() {
    registerFallbackValue(FakeBuildContext());
  });

  setUp(() {
    mockAgeVerificationService = MockAgeVerificationService();
    mockMediaViewerAuthService = MockMediaViewerAuthService();
    mockContext = MockBuildContext();
    interceptor = MediaAuthInterceptor(
      ageVerificationService: mockAgeVerificationService,
      mediaViewerAuthService: mockMediaViewerAuthService,
    );

    // Default mock behavior for preference checks
    when(
      () => mockAgeVerificationService.shouldHideAdultContent,
    ).thenReturn(false);
    when(
      () => mockAgeVerificationService.shouldAutoShowAdultContent,
    ).thenReturn(false);
  });

  group('MediaAuthInterceptor - 401 handling', () {
    test(
      'returns null when user is not verified and denies confirmation',
      () async {
        // Arrange
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => false);

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, isNull);
        verify(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).called(1);
        verifyNever(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
      },
    );

    test(
      'creates auth header when user has alwaysShow preference and is verified',
      () async {
        // Arrange - shouldAutoShowAdultContent means verified + alwaysShow preference
        when(
          () => mockAgeVerificationService.shouldAutoShowAdultContent,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => {'Authorization': 'Nostr abc123token'},
        );

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, equals({'Authorization': 'Nostr abc123token'}));
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: 'abc123',
          ),
        ).called(1);
      },
    );

    test(
      'creates auth header when user confirms adult content access via dialog',
      () async {
        // Arrange - default askEachTime preference (shouldAutoShowAdultContent=false)
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => {'Authorization': 'Nostr abc123token'},
        );

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, equals({'Authorization': 'Nostr abc123token'}));
        verify(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).called(1);
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: 'abc123',
          ),
        ).called(1);
      },
    );

    test('includes serverUrl in auth header when provided', () async {
      // Arrange - auto-show mode
      when(
        () => mockAgeVerificationService.shouldAutoShowAdultContent,
      ).thenReturn(true);
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer(
        (_) async => {'Authorization': 'Nostr tokenWithServer'},
      );

      // Act
      final result = await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'xyz789',
        serverUrl: 'https://blossom.example.com',
        category: 'nudity',
      );

      // Assert
      expect(result, equals({'Authorization': 'Nostr tokenWithServer'}));
      verify(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: 'xyz789',
          serverUrl: 'https://blossom.example.com',
        ),
      ).called(1);
    });

    test('logs category for future extensibility', () async {
      // Arrange - auto-show mode
      when(
        () => mockAgeVerificationService.shouldAutoShowAdultContent,
      ).thenReturn(true);
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => {'Authorization': 'Nostr token'});

      // Act - Test with different category (future-proofing for violence, etc.)
      await interceptor.handleUnauthorizedMedia(
        context: mockContext,
        sha256Hash: 'abc123',
        category: 'violence',
      );

      // Assert - Should still work (currently only handles nudity/adult content)
      verify(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: 'abc123',
        ),
      ).called(1);
    });

    test(
      'returns null when BlossomAuthService fails to create header',
      () async {
        // Arrange - auto-show mode but auth service returns null
        when(
          () => mockAgeVerificationService.shouldAutoShowAdultContent,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert
        expect(result, isNull);
      },
    );
  });

  group('MediaAuthInterceptor - helper methods', () {
    test('canCreateAuthHeaders delegates to MediaViewerAuthService', () {
      // Arrange
      when(() => mockMediaViewerAuthService.canCreateHeaders).thenReturn(true);

      // Act
      final result = interceptor.canCreateAuthHeaders;

      // Assert
      expect(result, isTrue);
      verify(() => mockMediaViewerAuthService.canCreateHeaders).called(1);
    });
  });
}
