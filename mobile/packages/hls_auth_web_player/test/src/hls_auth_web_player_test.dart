import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hls_auth_web_player/hls_auth_web_player.dart';

import 'fake_hls_auth_web_runtime.dart';

void main() {
  group(HlsAuthWebPlayer, () {
    late FakeHlsAuthWebRuntime runtime;

    setUp(() {
      runtime = FakeHlsAuthWebRuntime();
    });

    Future<String?> constantHeader(String url, String method) async =>
        'Nostr constant';

    testWidgets('invokes overlayBuilder with the current status transitions', (
      tester,
    ) async {
      final observed = <HlsAuthWebPlaybackStatus>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HlsAuthWebPlayer(
            runtime: runtime,
            url: 'https://media.example/a.mp4',
            authHeader: constantHeader,
            overlayBuilder: (_, status) {
              observed.add(status);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(observed, contains(HlsAuthWebPlaybackStatus.ready));
    });

    testWidgets(
      'calls onStatusChanged with requiresAuth when origin returns 401',
      (tester) async {
        runtime.mp4Result = HlsAuthWebAttemptResult.requiresAuth;
        final statuses = <HlsAuthWebPlaybackStatus>[];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: HlsAuthWebPlayer(
              runtime: runtime,
              url: 'https://media.example/a.mp4',
              authHeader: constantHeader,
              onStatusChanged: statuses.add,
              overlayBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(statuses, contains(HlsAuthWebPlaybackStatus.requiresAuth));
      },
    );

    testWidgets('disposes the underlying runtime when the widget is removed', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HlsAuthWebPlayer(
            runtime: runtime,
            url: 'https://media.example/a.mp4',
            authHeader: constantHeader,
            overlayBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      expect(runtime.disposedViewTypes, isNotEmpty);
    });

    testWidgets(
      'swaps controllers when the URL changes and disposes the previous one',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: HlsAuthWebPlayer(
              runtime: runtime,
              url: 'https://media.example/first.mp4',
              authHeader: constantHeader,
              overlayBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: HlsAuthWebPlayer(
              runtime: runtime,
              url: 'https://media.example/second.mp4',
              authHeader: constantHeader,
              overlayBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(runtime.mp4Calls.map((c) => c.url).toList(), hasLength(2));
        expect(runtime.disposedViewTypes, isNotEmpty);
      },
    );
  });
}
