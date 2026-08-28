// ABOUTME: Tests for ownedDivineUsernameProvider (deletion name-ownership lookup).

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

    ProviderContainer containerWith({required ProfileRepository? repo}) {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          profileReadRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('passes a found name through from the repository', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => repository.lookupUsernameByPubkey(pubkeyHex: pubkey),
      ).thenAnswer(
        (_) async =>
            const DivineUsernameFound(name: 'Alice', canonical: 'alice'),
      );

      final result = await containerWith(
        repo: repository,
      ).read(ownedDivineUsernameProvider.future);

      expect(result, isA<DivineUsernameFound>());
      expect((result as DivineUsernameFound).canonical, equals('alice'));
    });

    test('passes a confirmed not-found through from the repository', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => repository.lookupUsernameByPubkey(pubkeyHex: pubkey),
      ).thenAnswer((_) async => const DivineUsernameNotFound());

      final result = await containerWith(
        repo: repository,
      ).read(ownedDivineUsernameProvider.future);

      expect(result, isA<DivineUsernameNotFound>());
    });

    test(
      'passes unknown through, never collapsing it to a false absence',
      () async {
        when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
        when(
          () => repository.lookupUsernameByPubkey(pubkeyHex: pubkey),
        ).thenAnswer((_) async => const DivineUsernameUnknown());

        final result = await containerWith(
          repo: repository,
        ).read(ownedDivineUsernameProvider.future);

        expect(result, isA<DivineUsernameUnknown>());
      },
    );

    test('is unknown when the repository lookup fails', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => repository.lookupUsernameByPubkey(pubkeyHex: pubkey),
      ).thenAnswer((_) async => throw Exception('lookup failed'));

      final result = await containerWith(
        repo: repository,
      ).read(ownedDivineUsernameProvider.future);

      expect(result, isA<DivineUsernameUnknown>());
    });

    test('is unknown when there is no signed-in pubkey', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(null);

      final result = await containerWith(
        repo: repository,
      ).read(ownedDivineUsernameProvider.future);

      expect(result, isA<DivineUsernameUnknown>());
    });

    test('is unknown when the profile repository is not ready', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);

      final result = await containerWith(
        repo: null,
      ).read(ownedDivineUsernameProvider.future);

      expect(result, isA<DivineUsernameUnknown>());
    });
  });
}
