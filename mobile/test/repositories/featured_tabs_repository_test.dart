// ABOUTME: Tests for FeaturedTabsRepository cache TTL and eligibility gating.
// ABOUTME: Covers the visibility matrix and stale-serve-then-drop behavior.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

FeaturedTabConfig _tab({
  String id = 'ft_a1b2c3d4',
  bool enabled = true,
  bool hasContent = true,
  bool visibleToMinors = false,
  Map<String, String> label = const {'default': 'Featured'},
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  return FeaturedTabConfig(
    id: id,
    slug: 'featured-slug',
    label: label,
    startsAt: startsAt,
    endsAt: endsAt,
    enabled: enabled,
    hasContent: hasContent,
    visibleToMinors: visibleToMinors,
  );
}

void main() {
  group(FeaturedTabsRepository, () {
    late _MockFunnelcakeApiClient apiClient;
    late DateTime clock;

    setUp(() {
      apiClient = _MockFunnelcakeApiClient();
      clock = DateTime.utc(2026, 2, 15, 12);
    });

    FeaturedTabsRepository buildRepository() {
      return FeaturedTabsRepository(
        apiClient: apiClient,
        now: () => clock,
      );
    }

    void stubTabs(List<FeaturedTabConfig> tabs, {int pollSeconds = 300}) {
      when(apiClient.getFeaturedTabs).thenAnswer(
        (_) async => FeaturedTabsResponse(
          tabs: tabs,
          pollInterval: Duration(seconds: pollSeconds),
        ),
      );
    }

    void stubFailure() {
      when(apiClient.getFeaturedTabs).thenThrow(
        const FunnelcakeException('offline'),
      );
    }

    group('eligibility', () {
      test('returns the tab when every gate passes', () async {
        stubTabs([_tab()]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isTrue);
        expect(snapshot.tab?.id, equals('ft_a1b2c3d4'));
      });

      test('drops a disabled tab', () async {
        stubTabs([_tab(enabled: false)]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab with no server-side content', () async {
        stubTabs([_tab(hasContent: false)]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab whose window has not opened', () async {
        stubTabs([_tab(startsAt: clock.add(const Duration(days: 1)))]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab whose window has closed', () async {
        stubTabs([_tab(endsAt: clock.subtract(const Duration(days: 1)))]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('hides a non-opted-in tab from a minor viewer', () async {
        stubTabs([_tab()]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: true);

        expect(snapshot.hasTab, isFalse);
      });

      test('shows an opted-in tab to a minor viewer', () async {
        stubTabs([_tab(visibleToMinors: true)]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: true);

        expect(snapshot.hasTab, isTrue);
      });

      test('drops a tab with no resolvable label', () async {
        stubTabs([_tab(label: const {})]);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('returns no tab when the server sends an empty list', () async {
        stubTabs(const []);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test(
        'takes the first eligible entry when several are returned',
        () async {
          stubTabs([
            _tab(id: 'ft_disabled', enabled: false),
            _tab(id: 'ft_winner'),
            _tab(id: 'ft_runner_up'),
          ]);

          final snapshot = await buildRepository().refresh(
            viewerIsMinor: false,
          );

          expect(snapshot.tab?.id, equals('ft_winner'));
        },
      );

      test('surfaces the server poll interval', () async {
        stubTabs([_tab()], pollSeconds: 120);

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.pollInterval, equals(const Duration(seconds: 120)));
      });
    });

    group('cache', () {
      test('serves the cached tab through a transient failure', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        stubFailure();
        clock = clock.add(const Duration(minutes: 1));
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isTrue);
      });

      test('drops the tab once the cache passes its grace window', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        stubFailure();
        clock = clock.add(const Duration(minutes: 30));
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('survives the failure of a poll on the server cadence', () async {
        // The cache is only ever read from a failed refresh, and the refresh
        // that fails is normally the scheduled poll — so the cache is already
        // a full poll interval old by the time it is needed. A grace window
        // equal to the cadence would expire exactly then and blink the tab out
        // on the first flaky request.
        final repository = buildRepository();
        stubTabs([_tab()]);
        final first = await repository.refresh(viewerIsMinor: false);
        expect(first.pollInterval, equals(const Duration(minutes: 5)));

        stubFailure();
        clock = clock.add(const Duration(minutes: 5, seconds: 2));
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isTrue);
      });

      test('drops the tab after two consecutive missed polls', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        stubFailure();
        clock = clock.add(const Duration(minutes: 5, seconds: 2));
        expect(
          (await repository.refresh(viewerIsMinor: false)).hasTab,
          isTrue,
        );

        clock = clock.add(const Duration(minutes: 5));
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('a superseded refresh does not become the cache', () async {
        // The poll, a foreground resume, and an age-gate change can all be in
        // flight at once. If a request issued before a server kill lands after
        // the one that removed the tab, the stale config it leaves behind gets
        // served to the next failed refresh and the killed tab comes back.
        final beforeKill = Completer<FeaturedTabsResponse>();
        final afterKill = Completer<FeaturedTabsResponse>();
        var call = 0;
        when(apiClient.getFeaturedTabs).thenAnswer((_) {
          call++;
          return call == 1 ? beforeKill.future : afterKill.future;
        });

        final repository = buildRepository();
        final stale = repository.refresh(viewerIsMinor: false);
        final fresh = repository.refresh(viewerIsMinor: false);

        afterKill.complete(
          const FeaturedTabsResponse(
            tabs: [],
            pollInterval: Duration(minutes: 5),
          ),
        );
        expect((await fresh).hasTab, isFalse);

        beforeKill.complete(
          FeaturedTabsResponse(
            tabs: [_tab()],
            pollInterval: const Duration(minutes: 5),
          ),
        );
        await stale;

        stubFailure();
        clock = clock.add(const Duration(minutes: 1));
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(
          snapshot.hasTab,
          isFalse,
          reason: 'the killed config must not be resurrected from cache',
        );
      });

      test('scales the grace window with a slower server cadence', () async {
        final repository = buildRepository();
        stubTabs([_tab()], pollSeconds: 3600);
        await repository.refresh(viewerIsMinor: false);

        stubFailure();
        clock = clock.add(const Duration(minutes: 61));
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isTrue);
      });

      test('returns no tab when the first fetch fails with no cache', () async {
        stubFailure();

        final snapshot = await buildRepository().refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('recovers on the next successful fetch after expiry', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        stubFailure();
        clock = clock.add(FeaturedTabsRepository.defaultCacheTtl);
        await repository.refresh(viewerIsMinor: false);

        stubTabs([_tab()]);
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isTrue);
      });

      test('re-gates the cached config for the current viewer', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        stubFailure();
        final snapshot = await repository.refresh(viewerIsMinor: true);

        expect(snapshot.hasTab, isFalse);
      });

      test('stops serving a cached tab after clearCache', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        repository.clearCache();
        stubFailure();
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });

      test('drops a tab the server has since killed', () async {
        final repository = buildRepository();
        stubTabs([_tab()]);
        await repository.refresh(viewerIsMinor: false);

        stubTabs(const []);
        final snapshot = await repository.refresh(viewerIsMinor: false);

        expect(snapshot.hasTab, isFalse);
      });
    });
  });
}
