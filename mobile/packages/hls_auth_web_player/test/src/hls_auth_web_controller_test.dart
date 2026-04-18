import 'package:flutter_test/flutter_test.dart';
import 'package:hls_auth_web_player/hls_auth_web_player.dart';

import 'fake_hls_auth_web_runtime.dart';

void main() {
  group(HlsAuthWebController, () {
    late FakeHlsAuthWebRuntime runtime;

    setUp(() {
      runtime = FakeHlsAuthWebRuntime();
    });

    Future<String?> constantHeader(String url, String method) async =>
        'Nostr base64payload';

    test('load fails when runtime is unsupported', () async {
      runtime.isSupported = false;
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a.mp4',
        authHeader: constantHeader,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, equals(HlsAuthWebPlaybackStatus.failure));
      expect(runtime.mp4Calls, isEmpty);
      expect(runtime.hlsCalls, isEmpty);
    });

    test('MP4 path forwards the authorization header on success', () async {
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a.mp4',
        authHeader: constantHeader,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, equals(HlsAuthWebPlaybackStatus.ready));
      expect(runtime.mp4Calls, hasLength(1));
      expect(
        runtime.mp4Calls.single.authorization,
        equals('Nostr base64payload'),
      );
      expect(runtime.hlsCalls, isEmpty);
    });

    test(
      'MP4 401 surfaces requiresAuth without attempting HLS fallback',
      () async {
        runtime.mp4Result = HlsAuthWebAttemptResult.requiresAuth;
        final controller = HlsAuthWebController(
          runtime: runtime,
          viewType: 'view',
          url: 'https://media.example/a.mp4',
          hlsFallbackUrl: 'https://media.example/a/hls/master.m3u8',
          authHeader: constantHeader,
        );
        addTearDown(controller.dispose);

        await controller.load();

        expect(
          controller.status,
          equals(HlsAuthWebPlaybackStatus.requiresAuth),
        );
        expect(runtime.hlsCalls, isEmpty);
      },
    );

    test('MP4 failure falls back to HLS when an HLS URL is provided', () async {
      runtime
        ..mp4Result = HlsAuthWebAttemptResult.failure
        ..hlsResult = HlsAuthWebAttemptResult.ok;
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a.mp4',
        hlsFallbackUrl: 'https://media.example/a/hls/master.m3u8',
        authHeader: constantHeader,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, equals(HlsAuthWebPlaybackStatus.ready));
      expect(runtime.hlsCalls, hasLength(1));
      expect(
        runtime.hlsCalls.single.url,
        equals('https://media.example/a/hls/master.m3u8'),
      );
    });

    test('MP4 failure without an HLS fallback reports failure', () async {
      runtime.mp4Result = HlsAuthWebAttemptResult.failure;
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a.mp4',
        authHeader: constantHeader,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, equals(HlsAuthWebPlaybackStatus.failure));
      expect(runtime.hlsCalls, isEmpty);
    });

    test('HLS fallback surfacing requiresAuth propagates the status', () async {
      runtime
        ..mp4Result = HlsAuthWebAttemptResult.failure
        ..hlsResult = HlsAuthWebAttemptResult.requiresAuth;
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a.mp4',
        hlsFallbackUrl: 'https://media.example/a/hls/master.m3u8',
        authHeader: constantHeader,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, equals(HlsAuthWebPlaybackStatus.requiresAuth));
    });

    test('primary HLS URL uses the HLS path and does not touch MP4', () async {
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a/hls/master.m3u8',
        authHeader: constantHeader,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, equals(HlsAuthWebPlaybackStatus.ready));
      expect(runtime.mp4Calls, isEmpty);
      expect(runtime.hlsCalls, hasLength(1));
    });

    test('dispose delegates to the runtime and is idempotent', () async {
      final controller = HlsAuthWebController(
        runtime: runtime,
        viewType: 'view',
        url: 'https://media.example/a.mp4',
        authHeader: constantHeader,
      );

      await controller.load();
      controller
        ..dispose()
        ..dispose();

      expect(runtime.disposedViewTypes, equals(const ['view']));
    });

    test(
      'notifies listeners on every status transition with distinct values',
      () async {
        final observed = <HlsAuthWebPlaybackStatus>[];
        final controller = HlsAuthWebController(
          runtime: runtime,
          viewType: 'view',
          url: 'https://media.example/a.mp4',
          authHeader: constantHeader,
        );
        addTearDown(controller.dispose);
        controller.addListener(() {
          observed.add(controller.status);
        });

        await controller.load();

        expect(
          observed,
          equals(const [
            HlsAuthWebPlaybackStatus.loading,
            HlsAuthWebPlaybackStatus.ready,
          ]),
        );
      },
    );
  });
}
