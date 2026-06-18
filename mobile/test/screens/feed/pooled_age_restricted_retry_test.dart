// ABOUTME: Tests age-verification retry wiring for pooled native feed videos.
// ABOUTME: Verifies successful auth reloads playback and failures surface feedback.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class _FakeBuildContext extends Fake implements BuildContext {}

const _videoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _pubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';
const _sha256 =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
const _videoUrl = 'https://media.divine.video/$_sha256/720p.mp4';

String get _failureText =>
    lookupAppLocalizations(const Locale('en')).videoErrorVerifyAgeFailed;

String get _signerUnreachableText => lookupAppLocalizations(
  const Locale('en'),
).videoErrorVerifyAgeSignerUnreachable;

AgeVerificationService _ageService({required bool verified}) {
  final service = _MockAgeVerificationService();
  when(() => service.isAdultContentVerified).thenReturn(verified);
  return service;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
  });

  group('retryAgeRestrictedPooledVideo', () {
    testWidgets('retries playback and clears status after auth succeeds', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      Map<String, String>? retryHeaders;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (headers) {
            retryCount++;
            retryHeaders = headers;
            return true;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      expect(retryHeaders, equals({'Authorization': 'Nostr token'}));
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ready,
      );
      expect(find.text(_failureText), findsNothing);
    });

    testWidgets('marks the video verifying during the retry and clears it '
        'after', (tester) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      final authCompleter = Completer<ViewerAuthResult>();
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) => authCompleter.future);

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) => true,
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);
      expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      // markVerifying runs synchronously before the auth await.
      expect(playbackStatusCubit.state.isVerifying(_videoId), isTrue);

      authCompleter.complete(
        const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );
      await tester.pump();
      await tester.pump();
      // Cleared in the finally once the retry resolves.
      expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);
    });

    testWidgets(
      'ignores duplicate retry calls while verification is in flight',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        final authCompleter = Completer<ViewerAuthResult>();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) => authCompleter.future);

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            retryPlayback: (_) {
              retryCount++;
              return true;
            },
          ),
        );

        await tester.tap(find.text('Verify'));
        await tester.pump();
        expect(playbackStatusCubit.state.isVerifying(_videoId), isTrue);

        await tester.tap(find.text('Verify'));
        await tester.pump();

        verify(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).called(1);

        authCompleter.complete(
          const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
        );
        await tester.pump();
        await tester.pump();

        expect(retryCount, 1);
        expect(playbackStatusCubit.state.isVerifying(_videoId), isFalse);
      },
    );

    testWidgets('keeps gate state and stays silent when auth is declined', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer((_) async => const ViewerAuthUnavailable());

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          // Declining the age dialog leaves the viewer unverified.
          ageVerificationService: _ageService(verified: false),
          retryPlayback: (_) {
            retryCount++;
            return true;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 0);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );
      // A deliberate decline must not surface a failure message.
      expect(find.text(_failureText), findsNothing);
    });

    testWidgets(
      'surfaces feedback when the viewer accepts but auth headers cannot be '
      'created',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        // handleUnauthorizedMedia returns null even though the viewer accepted
        // (e.g. a remote signer that failed to produce the viewer-auth header).
        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthUnavailable());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            ageVerificationService: _ageService(verified: true),
            retryPlayback: (_) {
              retryCount++;
              return true;
            },
          ),
        );

        playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump();

        expect(retryCount, 0);
        expect(
          playbackStatusCubit.state.statusFor(_videoId),
          PlaybackStatus.ageRestricted,
        );
        expect(find.text(_failureText), findsOneWidget);
      },
    );

    testWidgets('surfaces feedback when authenticated retry fails', (
      tester,
    ) async {
      final mediaAuthInterceptor = _MockMediaAuthInterceptor();
      final playbackStatusCubit = VideoPlaybackStatusCubit();
      var retryCount = 0;
      addTearDown(playbackStatusCubit.close);

      when(
        () => mediaAuthInterceptor.handleUnauthorizedMedia(
          context: any(named: 'context'),
          sha256Hash: _sha256,
          url: _videoUrl,
          serverUrl: 'https://media.divine.video',
          category: 'video',
        ),
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr token'}),
      );

      await tester.pumpWidget(
        _RetryHarness(
          mediaAuthInterceptor: mediaAuthInterceptor,
          playbackStatusCubit: playbackStatusCubit,
          retryPlayback: (_) {
            retryCount++;
            return false;
          },
        ),
      );

      playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(retryCount, 1);
      expect(
        playbackStatusCubit.state.statusFor(_videoId),
        PlaybackStatus.ageRestricted,
      );
      expect(find.text(_failureText), findsOneWidget);
    });

    testWidgets(
      'surfaces the connectivity message when the remote signer is unreachable',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        // A non-interactive remote signer timed out: distinct from a verify
        // failure, so the viewer is told to check their connection.
        when(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: _sha256,
            url: _videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => const ViewerAuthSignerUnreachable());

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            retryPlayback: (_) {
              retryCount++;
              return true;
            },
          ),
        );

        playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump();

        expect(retryCount, 0);
        expect(
          playbackStatusCubit.state.statusFor(_videoId),
          PlaybackStatus.ageRestricted,
        );
        // The distinct signer-unreachable copy, not the generic verify failure.
        expect(find.text(_signerUnreachableText), findsOneWidget);
        expect(find.text(_failureText), findsNothing);
      },
    );

    testWidgets(
      'refuses retry and surfaces feedback when sha256 cannot be resolved',
      (tester) async {
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        final playbackStatusCubit = VideoPlaybackStatusCubit();
        var retryCount = 0;
        addTearDown(playbackStatusCubit.close);

        // No sha256 field and a URL without a 64-hex blob segment, so
        // _resolveSha256 returns null and the hash-bound BUD-01 path is
        // unavailable. The retry must refuse rather than fall back to a
        // URL-bound NIP-98 token that would not authenticate the variants.
        final video = VideoEvent(
          id: _videoId,
          pubkey: _pubkey,
          createdAt: 1704067200,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
          videoUrl: 'https://media.divine.video/video.mp4',
        );

        await tester.pumpWidget(
          _RetryHarness(
            mediaAuthInterceptor: mediaAuthInterceptor,
            playbackStatusCubit: playbackStatusCubit,
            video: video,
            retryPlayback: (_) {
              retryCount++;
              return true;
            },
          ),
        );

        playbackStatusCubit.report(_videoId, PlaybackStatus.ageRestricted);

        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump();

        expect(retryCount, 0);
        verifyNever(
          () => mediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
            category: any(named: 'category'),
          ),
        );
        expect(
          playbackStatusCubit.state.statusFor(_videoId),
          PlaybackStatus.ageRestricted,
        );
        expect(find.text(_failureText), findsOneWidget);
      },
    );
  });
}

class _RetryHarness extends StatelessWidget {
  const _RetryHarness({
    required this.mediaAuthInterceptor,
    required this.playbackStatusCubit,
    required this.retryPlayback,
    this.video,
    this.ageVerificationService,
  });

  final MediaAuthInterceptor mediaAuthInterceptor;
  final VideoPlaybackStatusCubit playbackStatusCubit;
  final bool Function(Map<String, String>) retryPlayback;
  final VideoEvent? video;
  final AgeVerificationService? ageVerificationService;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mediaAuthInterceptorProvider.overrideWithValue(mediaAuthInterceptor),
        if (ageVerificationService != null)
          ageVerificationServiceProvider.overrideWithValue(
            ageVerificationService!,
          ),
      ],
      child: BlocProvider<VideoPlaybackStatusCubit>.value(
        value: playbackStatusCubit,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return TextButton(
                  onPressed: () => retryAgeRestrictedPooledVideo(
                    context: context,
                    ref: ref,
                    video: video ?? _video,
                    index: 0,
                    retryPlayback: retryPlayback,
                  ),
                  child: const Text('Verify'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final _video = VideoEvent(
  id: _videoId,
  pubkey: _pubkey,
  createdAt: 1704067200,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
  videoUrl: _videoUrl,
  sha256: _sha256,
);
