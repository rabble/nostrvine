// ABOUTME: Unit tests for FollowListSearchBloc.
// ABOUTME: Covers query gating, name resolution, filtering and repo swap.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full 64-character hex pubkeys — never truncate in app code, logs, or
// stored state. Full IDs only.
const String _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _carolPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _subjectPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

const List<String> _allPubkeys = [_alicePubkey, _bobPubkey, _carolPubkey];

/// Long enough to clear the 300 ms search debounce.
const _pastDebounce = Duration(milliseconds: 400);

UserProfile _profile({
  required String pubkey,
  String? displayName,
  String? nip05,
}) {
  return UserProfile(
    pubkey: pubkey,
    displayName: displayName,
    nip05: nip05,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'event_for_$pubkey',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FollowListKind.followers);
  });

  group(FollowListSearchBloc, () {
    late _MockProfileRepository profileRepository;
    late _MockFollowRepository followRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
      followRepository = _MockFollowRepository();
      // Default: the API answers nothing, so every assertion below is about
      // on-device matching unless it stubs this differently.
      when(
        () => followRepository.searchFollowList(
          pubkey: any(named: 'pubkey'),
          query: any(named: 'query'),
          kind: any(named: 'kind'),
        ),
      ).thenAnswer((_) async => const <String>{});
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer(
        (_) async => {
          _alicePubkey: _profile(pubkey: _alicePubkey, displayName: 'Alice'),
          _bobPubkey: _profile(
            pubkey: _bobPubkey,
            displayName: 'Bob',
            nip05: '_@bobby.divine.video',
          ),
          _carolPubkey: _profile(pubkey: _carolPubkey, displayName: 'Carol'),
        },
      );
    });

    FollowListSearchBloc createBloc({bool withRepository = true}) {
      return FollowListSearchBloc(
        followRepository: followRepository,
        subjectPubkey: _subjectPubkey,
        listKind: FollowListKind.followers,
        profileRepository: withRepository ? profileRepository : null,
      );
    }

    test('starts with no query and shows every pubkey', () {
      final bloc = createBloc();
      addTearDown(bloc.close);

      expect(bloc.state.isActive, isFalse);
      expect(bloc.state.visibleFrom(_allPubkeys), _allPubkeys);
    });

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'ignores a query shorter than the minimum and resolves no profiles',
      build: createBloc,
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('a', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.query, isEmpty);
        expect(bloc.state.visibleFrom(_allPubkeys), _allPubkeys);
        verifyNever(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        );
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'filters the list down to the display name that matches',
      build: createBloc,
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'matches on the NIP-05 handle as well as the display name',
      build: createBloc,
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('bobby', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_bobPubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'matches a pasted hex pubkey prefix',
      build: createBloc,
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('cccccc', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_carolPubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'falls back to the generated name when no repository is wired yet',
      build: () => createBloc(withRepository: false),
      act: (bloc) => bloc.add(
        FollowListSearchQueryChanged(
          UserProfile.defaultDisplayNameFor(_bobPubkey),
          _allPubkeys,
        ),
      ),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_bobPubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'resolves names once a late profile repository arrives',
      build: () => createBloc(withRepository: false),
      act: (bloc) async {
        bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
        await Future<void>.delayed(_pastDebounce);
        bloc.add(FollowListSearchProfileRepositoryChanged(profileRepository));
      },
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'keeps matching on generated names when the batch fetch throws',
      build: createBloc,
      setUp: () {
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenThrow(Exception('offline'));
      },
      act: (bloc) => bloc.add(
        FollowListSearchQueryChanged(
          UserProfile.defaultDisplayNameFor(_carolPubkey),
          _allPubkeys,
        ),
      ),
      wait: _pastDebounce,
      errors: () => [isA<Exception>()],
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_carolPubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'keeps a row the API matched but this device has no name for',
      build: createBloc,
      setUp: () {
        // The cold-cache case: no profile resolves on device, so on-device
        // matching can only see generated fallback names.
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => const {});
        when(
          () => followRepository.searchFollowList(
            pubkey: _subjectPubkey,
            query: 'ali',
            kind: FollowListKind.followers,
          ),
        ).thenAnswer((_) async => const {_alicePubkey});
      },
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'unions API matches with on-device matches',
      build: createBloc,
      setUp: () {
        // The API knows Carol but not Bob; on-device only knows Bob's name.
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => {
            _bobPubkey: _profile(pubkey: _bobPubkey, displayName: 'Zeta Bob'),
          },
        );
        when(
          () => followRepository.searchFollowList(
            pubkey: _subjectPubkey,
            query: 'zeta',
            kind: FollowListKind.followers,
          ),
        ).thenAnswer((_) async => const {_carolPubkey});
      },
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('zeta', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_bobPubkey, _carolPubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'drops API matches from the previous query',
      build: createBloc,
      setUp: () {
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => const {});
        when(
          () => followRepository.searchFollowList(
            pubkey: _subjectPubkey,
            query: 'ali',
            kind: FollowListKind.followers,
          ),
        ).thenAnswer((_) async => const {_alicePubkey});
      },
      act: (bloc) async {
        bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
        await Future<void>.delayed(_pastDebounce);
        bloc.add(const FollowListSearchQueryChanged('zzz', _allPubkeys));
      },
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.remoteMatches, isEmpty);
        expect(bloc.state.visibleFrom(_allPubkeys), isEmpty);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'skips the API search when there is no subject pubkey',
      build: () => FollowListSearchBloc(
        followRepository: followRepository,
        subjectPubkey: '',
        listKind: FollowListKind.followers,
        profileRepository: profileRepository,
      ),
      act: (bloc) =>
          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys)),
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
        verifyNever(
          () => followRepository.searchFollowList(
            pubkey: any(named: 'pubkey'),
            query: any(named: 'query'),
            kind: any(named: 'kind'),
          ),
        );
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'retries a chunk whose profile fetch threw instead of pinning it',
      build: createBloc,
      setUp: () {
        var attempt = 0;
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async {
          if (attempt++ == 0) throw Exception('offline');
          return {
            _alicePubkey: _profile(pubkey: _alicePubkey, displayName: 'Alice'),
          };
        });
      },
      act: (bloc) async {
        bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
        await Future<void>.delayed(_pastDebounce);
        bloc.add(const FollowListSearchQueryChanged('alic', _allPubkeys));
      },
      wait: _pastDebounce,
      errors: () => [isA<Exception>()],
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'drops terms resolved through the previous profile repository',
      build: createBloc,
      setUp: () {
        // This repository cannot reach Alice, so she is only matchable by her
        // generated name until a better one arrives.
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => const {});
      },
      act: (bloc) async {
        bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
        await Future<void>.delayed(_pastDebounce);

        final replacement = _MockProfileRepository();
        when(
          () => replacement.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
        ).thenAnswer(
          (_) async => {
            _alicePubkey: _profile(pubkey: _alicePubkey, displayName: 'Alice'),
          },
        );
        bloc.add(FollowListSearchProfileRepositoryChanged(replacement));
      },
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'runs the API search once the subject pubkey arrives',
      build: () => FollowListSearchBloc(
        followRepository: followRepository,
        subjectPubkey: '',
        listKind: FollowListKind.followers,
        profileRepository: profileRepository,
      ),
      setUp: () {
        // Nothing resolves on device, so only the API can produce this match.
        when(
          () => profileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => const {});
        when(
          () => followRepository.searchFollowList(
            pubkey: _subjectPubkey,
            query: 'ali',
            kind: FollowListKind.followers,
          ),
        ).thenAnswer((_) async => const {_alicePubkey});
      },
      act: (bloc) async {
        bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
        await Future<void>.delayed(_pastDebounce);
        expect(bloc.state.visibleFrom(_allPubkeys), isEmpty);

        bloc.add(const FollowListSearchSubjectPubkeyChanged(_subjectPubkey));
      },
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
      },
    );

    blocTest<FollowListSearchBloc, FollowListSearchState>(
      'clearing the query restores the full list',
      build: createBloc,
      act: (bloc) async {
        bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
        await Future<void>.delayed(_pastDebounce);
        bloc.add(const FollowListSearchQueryChanged('', _allPubkeys));
      },
      wait: _pastDebounce,
      verify: (bloc) {
        expect(bloc.state.isActive, isFalse);
        expect(bloc.state.visibleFrom(_allPubkeys), _allPubkeys);
      },
    );
  });
}
