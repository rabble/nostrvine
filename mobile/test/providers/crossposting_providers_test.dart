// ABOUTME: Tests reactive OAuth wiring and disposal for crossposting providers
// ABOUTME: Uses the injectable client factory without generated Riverpod code

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

final _authSelectorProvider = StateProvider<AuthService>((_) {
  throw StateError('Must be overridden');
});

void main() {
  test('auth changes rebuild and dispose owner-bound API clients', () async {
    final firstAuth = _MockAuthService();
    final secondAuth = _MockAuthService();
    final firstClient = _MockCrosspostingApiClient();
    final secondClient = _MockCrosspostingApiClient();
    when(firstAuth.getBoundDivineAccessToken).thenAnswer((_) async => 'first');
    when(
      secondAuth.getBoundDivineAccessToken,
    ).thenAnswer((_) async => 'second');
    when(firstClient.close).thenReturn(null);
    when(secondClient.close).thenReturn(null);
    final readers = <CrosspostingAccessTokenReader>[];
    final container = ProviderContainer(
      overrides: [
        _authSelectorProvider.overrideWith((_) => firstAuth),
        authServiceProvider.overrideWith(
          (ref) => ref.watch(_authSelectorProvider),
        ),
        crosspostingApiClientFactoryProvider.overrideWithValue((reader) {
          readers.add(reader);
          return readers.length == 1 ? firstClient : secondClient;
        }),
      ],
    );

    expect(container.read(crosspostingApiClientProvider), same(firstClient));
    expect(await readers.single(), 'first');
    container.read(_authSelectorProvider.notifier).state = secondAuth;
    await Future<void>.delayed(Duration.zero);

    expect(container.read(crosspostingApiClientProvider), same(secondClient));
    expect(await readers.last(), 'second');
    expect(readers, hasLength(2));
    verify(firstClient.close).called(1);
    verifyNever(secondClient.close);

    container.dispose();

    verify(secondClient.close).called(1);
  });
}
