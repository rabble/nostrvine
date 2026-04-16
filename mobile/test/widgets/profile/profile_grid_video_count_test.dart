// ABOUTME: Tests for ProfileGridView video-count plumbing
// ABOUTME: Verifies fallback expression and screen→grid loading-signal forwarding

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';

void main() {
  group('ProfileGridView.resolveDisplayVideoCount', () {
    test(
      'returns null when totalVideoCount is null and still loading — '
      'so header shows the loading dash',
      () {
        expect(
          ProfileGridView.resolveDisplayVideoCount(
            totalVideoCount: null,
            isLoadingVideos: true,
            loadedVideosLength: 50,
          ),
          isNull,
        );
      },
    );

    test(
      'falls back to loadedVideosLength when totalVideoCount is null and '
      'loading has settled — so Nostr-only profiles show videos.length',
      () {
        expect(
          ProfileGridView.resolveDisplayVideoCount(
            totalVideoCount: null,
            isLoadingVideos: false,
            loadedVideosLength: 50,
          ),
          equals(50),
        );
      },
    );

    test(
      'prefers totalVideoCount when available, even while still loading',
      () {
        expect(
          ProfileGridView.resolveDisplayVideoCount(
            totalVideoCount: 142,
            isLoadingVideos: true,
            loadedVideosLength: 50,
          ),
          equals(142),
        );
      },
    );

    test('uses totalVideoCount once settled', () {
      expect(
        ProfileGridView.resolveDisplayVideoCount(
          totalVideoCount: 142,
          isLoadingVideos: false,
          loadedVideosLength: 50,
        ),
        equals(142),
      );
    });

    test(
      'returns 0 when loaded list is empty and nothing else is available',
      () {
        expect(
          ProfileGridView.resolveDisplayVideoCount(
            totalVideoCount: null,
            isLoadingVideos: false,
            loadedVideosLength: 0,
          ),
          equals(0),
        );
      },
    );
  });

  group(
    'ProfileViewSwitcher forwards isFetchingTotalCount as isLoadingVideos',
    () {
      final now = DateTime.now();
      final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
      const testUserHex =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      const testUserNpub =
          'npub10zjuyx63vmwpga9kfh0hg49l08ntt4455ac5skfm785xddeuyuuqt7gxpj';

      final mockVideos = [
        VideoEvent(
          id: 'v0',
          pubkey: testUserHex,
          createdAt: nowUnix,
          content: 'Video 0',
          timestamp: now,
          title: 'Video 0',
          videoUrl: 'https://example.com/v0.mp4',
        ),
      ];

      Widget buildSubject({
        required bool isFetchingTotalCount,
        int? totalVideoCount,
      }) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileViewSwitcher(
              npub: testUserNpub,
              userIdHex: testUserHex,
              isOwnProfile: false,
              videos: mockVideos,
              videoIndex: null, // grid mode
              totalVideoCount: totalVideoCount,
              isFetchingTotalCount: isFetchingTotalCount,
              scrollController: ScrollController(),
              onSetupProfile: () {},
              onEditProfile: () {},
              onOpenClips: () {},
              onOpenAnalytics: () {},
            ),
          ),
        );
      }

      testWidgets(
        'passes isLoadingVideos: true when isFetchingTotalCount is true',
        (tester) async {
          // ProfileGridView's build accesses repository providers that aren't
          // scaffolded here. Its runtime errors are irrelevant — we only read
          // the widget instance's props from the element tree.
          final previousOnError = FlutterError.onError;
          FlutterError.onError = (_) {};
          addTearDown(() => FlutterError.onError = previousOnError);

          await tester.pumpWidget(buildSubject(isFetchingTotalCount: true));

          final grid = tester.widget<ProfileGridView>(
            find.byType(ProfileGridView),
          );
          expect(grid.isLoadingVideos, isTrue);
        },
      );

      testWidgets(
        'passes isLoadingVideos: false when isFetchingTotalCount is false',
        (tester) async {
          final previousOnError = FlutterError.onError;
          FlutterError.onError = (_) {};
          addTearDown(() => FlutterError.onError = previousOnError);

          await tester.pumpWidget(buildSubject(isFetchingTotalCount: false));

          final grid = tester.widget<ProfileGridView>(
            find.byType(ProfileGridView),
          );
          expect(grid.isLoadingVideos, isFalse);
        },
      );

      testWidgets('forwards totalVideoCount unchanged', (tester) async {
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (_) {};
        addTearDown(() => FlutterError.onError = previousOnError);

        await tester.pumpWidget(
          buildSubject(isFetchingTotalCount: false, totalVideoCount: 42),
        );

        final grid = tester.widget<ProfileGridView>(
          find.byType(ProfileGridView),
        );
        expect(grid.totalVideoCount, equals(42));
      });
    },
  );
}
