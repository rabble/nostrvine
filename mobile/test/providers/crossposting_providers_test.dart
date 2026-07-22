// ABOUTME: Tests reactive OAuth wiring and disposal for crossposting providers
// ABOUTME: Uses the injectable client factory without generated Riverpod code

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

final _oauthSelectorProvider = StateProvider<KeycastOAuth>((_) {
  throw StateError('Must be overridden');
});

void main() {
  test('OAuth changes rebuild and dispose API clients', () async {
    final firstOAuth = _MockKeycastOAuth();
    final secondOAuth = _MockKeycastOAuth();
    final firstClient = _MockCrosspostingApiClient();
    final secondClient = _MockCrosspostingApiClient();
    when(firstClient.close).thenReturn(null);
    when(secondClient.close).thenReturn(null);
    final builtFor = <KeycastOAuth>[];
    final container = ProviderContainer(
      overrides: [
        _oauthSelectorProvider.overrideWith((_) => firstOAuth),
        oauthClientProvider.overrideWith(
          (ref) => ref.watch(_oauthSelectorProvider),
        ),
        crosspostingApiClientFactoryProvider.overrideWithValue((oauthClient) {
          builtFor.add(oauthClient);
          return identical(oauthClient, firstOAuth)
              ? firstClient
              : secondClient;
        }),
      ],
    );

    expect(container.read(crosspostingApiClientProvider), same(firstClient));
    container.read(_oauthSelectorProvider.notifier).state = secondOAuth;
    await Future<void>.delayed(Duration.zero);

    expect(container.read(crosspostingApiClientProvider), same(secondClient));
    expect(builtFor, [firstOAuth, secondOAuth]);
    verify(firstClient.close).called(1);
    verifyNever(secondClient.close);

    container.dispose();

    verify(secondClient.close).called(1);
  });
}
