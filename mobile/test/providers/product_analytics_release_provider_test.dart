// ABOUTME: Proves product analytics uses the running app version.
// ABOUTME: Prevents release coverage from collapsing into the old 1.0.0 constant.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProductEventQueue extends Mock implements ProductEventQueue {}

class _MockViewEventPublisher extends Mock implements ViewEventPublisher {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a staging dogfood build may use a unique smoke-test release', () {
    expect(
      resolveProductAnalyticsRelease(
        runtimeVersion: '1.2.3',
        environment: 'STAGING',
        stagingOverride: 'staging-smoke-0123456789abcdef0123456789abcdef',
      ),
      'staging-smoke-0123456789abcdef0123456789abcdef',
    );
  });

  test('production and malformed overrides use the real app version', () {
    expect(
      resolveProductAnalyticsRelease(
        runtimeVersion: '1.2.3',
        environment: 'PRODUCTION',
        stagingOverride: 'staging-smoke-0123456789abcdef0123456789abcdef',
      ),
      '1.2.3',
    );
    expect(
      resolveProductAnalyticsRelease(
        runtimeVersion: '1.2.3',
        environment: 'STAGING',
        stagingOverride: 'anything-else',
      ),
      '1.2.3',
    );
  });

  test('product analytics reports the running app version', () async {
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase.test(NativeDatabase.memory());
    final authService = _MockAuthService();
    final queue = _MockProductEventQueue();
    final viewPublisher = _MockViewEventPublisher();

    when(() => authService.currentPublicKeyHex).thenReturn(null);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => authService.registerBeforeSessionTeardownCallback(any()),
    ).thenReturn(() {});

    final container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWithValue('2026.8.21-dogfood'),
        databaseProvider.overrideWithValue(database),
        authServiceProvider.overrideWithValue(authService),
        productEventQueueProvider.overrideWithValue(queue),
        viewEventPublisherProvider.overrideWithValue(viewPublisher),
        viewEventRetryServiceProvider.overrideWithValue(null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(
      container.read(analyticsServiceProvider).productAnalyticsRelease,
      '2026.8.21-dogfood',
    );
  });
}
