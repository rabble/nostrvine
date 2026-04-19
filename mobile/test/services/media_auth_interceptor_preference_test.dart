// ABOUTME: TDD tests for MediaAuthInterceptor respecting AdultContentPreference
// ABOUTME: Tests neverShow filtering, alwaysShow auto-auth, and askEachTime dialog flow

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
  });

  group('MediaAuthInterceptor - preference handling', () {
    test('shouldFilterContent returns true when preference is neverShow', () {
      when(
        () => mockAgeVerificationService.shouldHideAdultContent,
      ).thenReturn(true);

      expect(interceptor.shouldFilterContent, isTrue);
    });

    test(
      'shouldFilterContent returns false when preference is askEachTime',
      () {
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(false);

        expect(interceptor.shouldFilterContent, isFalse);
      },
    );

    test(
      'handleUnauthorizedMedia returns null when preference is neverShow',
      () async {
        // Arrange - neverShow means we should hide content
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(true);

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - returns null immediately, no auth attempt
        expect(result, isNull);
        verifyNever(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
        verifyNever(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        );
      },
    );

    test(
      'handleUnauthorizedMedia auto-creates auth when alwaysShow and verified',
      () async {
        // Arrange - alwaysShow preference, already verified
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.shouldAutoShowAdultContent,
        ).thenReturn(true);
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => {'Authorization': 'Nostr autoToken'});

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - auto auth header created, no dialog shown
        expect(result, equals({'Authorization': 'Nostr autoToken'}));
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
      'handleUnauthorizedMedia shows dialog when askEachTime and verified',
      () async {
        // Arrange - askEachTime preference, already verified for age
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.shouldAutoShowAdultContent,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.shouldAskForAdultContent,
        ).thenReturn(true);
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
        ).thenAnswer((_) async => {'Authorization': 'Nostr dialogToken'});

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - dialog was shown, auth header created after confirmation
        expect(result, equals({'Authorization': 'Nostr dialogToken'}));
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

    test(
      'handleUnauthorizedMedia returns null when askEachTime and user declines',
      () async {
        // Arrange - askEachTime preference, user declines in dialog
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.shouldAutoShowAdultContent,
        ).thenReturn(false);
        when(
          () => mockAgeVerificationService.shouldAskForAdultContent,
        ).thenReturn(true);
        when(() => mockContext.mounted).thenReturn(true);
        when(
          () => mockAgeVerificationService.verifyAdultContentAccess(any()),
        ).thenAnswer((_) async => false);

        // Act
        final result = await interceptor.handleUnauthorizedMedia(
          context: mockContext,
          sha256Hash: 'abc123',
          category: 'nudity',
        );

        // Assert - user declined, no auth header
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
  });
}
