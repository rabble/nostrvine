// ABOUTME: Tests for userListsProvider reactivity to authentication transitions
// ABOUTME: Covers sign-in, sign-out, and active-account switches.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Full-length 64-char Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

UserList _buildList({
  required String id,
  required String name,
  List<String> pubkeys = const [],
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: _frozenNow,
    updatedAt: _frozenNow,
  );
}

void main() {
  group(userListsProvider, () {
    late _MockAuthService mockAuthService;
    late _MockPeopleListsRepository mockRepository;
    late StreamController<AuthState> authStateController;
    late StreamController<List<UserList>> ownerAListsController;
    late StreamController<List<UserList>> ownerBListsController;

    setUp(() {
      mockAuthService = _MockAuthService();
      mockRepository = _MockPeopleListsRepository();
      authStateController = StreamController<AuthState>.broadcast();
      ownerAListsController = StreamController<List<UserList>>.broadcast();
      ownerBListsController = StreamController<List<UserList>>.broadcast();

      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);
      when(() => mockAuthService.authState).thenReturn(
        AuthState.unauthenticated,
      );
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

      when(
        () => mockRepository.watchLists(ownerPubkey: _ownerA),
      ).thenAnswer((_) => ownerAListsController.stream);
      when(
        () => mockRepository.watchLists(ownerPubkey: _ownerB),
      ).thenAnswer((_) => ownerBListsController.stream);
    });

    tearDown(() async {
      await authStateController.close();
      if (!ownerAListsController.isClosed) {
        await ownerAListsController.close();
      }
      if (!ownerBListsController.isClosed) {
        await ownerBListsController.close();
      }
    });

    ProviderContainer buildContainer() {
      return ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          peopleListsRepositoryProvider.overrideWithValue(mockRepository),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWithValue(true),
        ],
      );
    }

    test(
      'emits empty list when auth state is unauthenticated',
      () async {
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.unauthenticated);
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

        final container = buildContainer();
        addTearDown(container.dispose);

        // Trigger initial build by listening.
        final subscription = container.listen(
          userListsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        // Flush the stream's first value.
        await Future<void>.delayed(Duration.zero);

        final value = container.read(userListsProvider);
        expect(value.hasValue, isTrue);
        expect(value.value, isEmpty);
        verifyNever(
          () => mockRepository.watchLists(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'rebuilds and watches repository for new owner when auth '
      'transitions from unauthenticated to authenticated',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);

        final subscription = container.listen(
          userListsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await Future<void>.delayed(Duration.zero);

        // Initially unauthenticated — repo should not have been watched.
        verifyNever(
          () => mockRepository.watchLists(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );

        // Transition: user signs in. authService now reports ownerA.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_ownerA);

        // Invalidating currentAuthStateProvider simulates the
        // authStateStream listener firing inside currentAuthStateProvider.
        container.invalidate(currentAuthStateProvider);

        await Future<void>.delayed(Duration.zero);

        // Emit some lists from the repo stream.
        ownerAListsController.add([
          _buildList(id: 'list-a1', name: 'Friends'),
        ]);

        await Future<void>.delayed(Duration.zero);

        final value = container.read(userListsProvider);
        expect(value.hasValue, isTrue);
        expect(value.value, hasLength(1));
        expect(value.value!.first.id, equals('list-a1'));
        verify(
          () => mockRepository.watchLists(ownerPubkey: _ownerA),
        ).called(1);
      },
    );

    test(
      'resubscribes to new owner repository after sign-out then sign-in '
      'as a different account',
      () async {
        // Start authenticated as owner A.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_ownerA);

        final container = buildContainer();
        addTearDown(container.dispose);

        final subscription = container.listen(
          userListsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await Future<void>.delayed(Duration.zero);

        ownerAListsController.add([
          _buildList(id: 'list-a1', name: 'Friends'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(userListsProvider).value,
          hasLength(1),
        );
        verify(
          () => mockRepository.watchLists(ownerPubkey: _ownerA),
        ).called(1);

        // Sign out — auth service emits `unauthenticated`. The stream
        // event invalidates `currentAuthStateProvider`, which rebuilds
        // with a genuinely different enum value and propagates.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.unauthenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(null);
        authStateController.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(userListsProvider).value,
          isEmpty,
        );

        // Sign in as owner B.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_ownerB);
        authStateController.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        ownerBListsController.add([
          _buildList(id: 'list-b1', name: 'Crew'),
          _buildList(id: 'list-b2', name: 'Inner Circle'),
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final value = container.read(userListsProvider);
        expect(value.hasValue, isTrue);
        expect(value.value, hasLength(2));
        expect(
          value.value!.map((l) => l.id),
          containsAll(<String>['list-b1', 'list-b2']),
        );
        verify(
          () => mockRepository.watchLists(ownerPubkey: _ownerB),
        ).called(1);
      },
    );
  });
}
