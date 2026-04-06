import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/live/go_live_page.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

Iterable<String> _flattenPaths(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route.path;
      yield* _flattenPaths(route.routes);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoLivePage', () {
    test(
      'Go Live route is available only when livestreamingBeta is enabled',
      () {
        expect(
          _flattenPaths(buildLiveRoutes(liveEnabled: true)),
          contains(GoLivePage.path),
        );
        expect(
          _flattenPaths(buildLiveRoutes(liveEnabled: false)),
          isNot(contains(GoLivePage.path)),
        );
      },
    );

    testWidgets('renders room setup fields and start action', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final mockLiveRepository = _MockLiveRepository();
      final mockLiveApiService = _MockLiveApiService();
      final mockAuthService = createMockAuthService();
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('host-pubkey');

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
          ],
          home: const GoLivePage(),
        ),
      );
      await tester.pump();

      expect(find.text('Go live'), findsOneWidget);
      expect(find.text('Start live now'), findsOneWidget);
      expect(find.text('Room title'), findsOneWidget);
    });
  });
}
