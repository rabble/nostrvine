// ABOUTME: Tests for ownedDivineUsernameProvider (gates the burn toggle).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/owned_divine_username_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('ownedDivineUsernameProvider', () {
    late _MockAuthService auth;
    late _MockProfileRepository repository;
    const pubkey =
        '156dd13a1f8a488037fa1b43ad934a5e58644a1d6e1ad6697a02c2e93b8b013b';

    setUp(() {
      auth = _MockAuthService();
      repository = _MockProfileRepository();
    });

    test('resolves the owned name from the repository', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () =>
            repository.getUsernameByPubkey(pubkeyHex: any(named: 'pubkeyHex')),
      ).thenAnswer((_) async => 'alice');
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ownedDivineUsernameProvider.future),
        equals('alice'),
      );
    });

    test('returns null when there is no signed-in pubkey', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(null);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(ownedDivineUsernameProvider.future), isNull);
    });

    test('returns null when the profile repository is not ready', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(ownedDivineUsernameProvider.future), isNull);
    });
  });
}
