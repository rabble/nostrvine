// ABOUTME: BLoC backing the search field on the followers/following screens
// ABOUTME: Owns the query and lazily resolves display names for matching

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:profile_repository/profile_repository.dart';

part 'follow_list_search_event.dart';
part 'follow_list_search_state.dart';

/// BLoC that filters a follower/following list by a search query.
///
/// The list itself stays owned by the screen's list BLoC — this one only
/// holds the query plus the display names needed to match against it, and
/// exposes the filter through [FollowListSearchState.visibleFrom]. That keeps
/// the two lists from drifting apart: there is exactly one source of pubkeys.
///
/// Matching runs from two sides, and a row qualifies if either one hits:
///
///  * **Server-side.** [FollowRepository.searchFollowList] asks the API which
///    members of this list match, which is the only path that can find someone
///    on a device with a cold profile cache. It answers only for accounts the
///    API has indexed, and returns nothing at all where the endpoint is not
///    deployed yet.
///  * **On-device.** Names are resolved for the candidate list in chunks,
///    re-emitting after each one so results refine progressively instead of
///    blocking on the whole list. This keeps working offline and covers list
///    members the API does not know. A pubkey whose profile never resolves
///    still matches on its deterministic fallback name — the same name the
///    list tile renders.
class FollowListSearchBloc
    extends Bloc<FollowListSearchEvent, FollowListSearchState> {
  /// Creates the search BLoC.
  ///
  /// [subjectPubkey] is whose list this is, and [listKind] which side of it —
  /// together they address the server-side search. Pass an empty
  /// [subjectPubkey] to run on-device matching only.
  ///
  /// [profileRepository] is nullable because `profileRepositoryProvider` is
  /// gated on Nostr readiness and hands over the real instance after cold
  /// start. The late instance arrives via
  /// [FollowListSearchProfileRepositoryChanged].
  FollowListSearchBloc({
    required FollowRepository followRepository,
    required String subjectPubkey,
    required FollowListKind listKind,
    ProfileRepository? profileRepository,
  }) : _followRepository = followRepository,
       _subjectPubkey = subjectPubkey,
       _listKind = listKind,
       _profileRepository = profileRepository,
       super(const FollowListSearchState()) {
    on<FollowListSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<FollowListSearchProfileRepositoryChanged>(_onProfileRepositoryChanged);
  }

  final FollowRepository _followRepository;
  final String _subjectPubkey;
  final FollowListKind _listKind;

  /// Swappable rather than final for the same reason as
  /// `ConversationListBloc._profileRepository`: re-pointing this one field is
  /// cheaper than re-keying the `BlocProvider`, which would tear down the
  /// screen subtree and the user's in-flight query with it.
  ProfileRepository? _profileRepository;

  Future<void> _onQueryChanged(
    FollowListSearchQueryChanged event,
    Emitter<FollowListSearchState> emit,
  ) async {
    final trimmed = event.query.trim();
    // A single character matches almost everything and would fan out a
    // profile fetch per list entry, so treat it as "not searching".
    final query = trimmed.length < minSearchQueryLength ? '' : trimmed;

    // Emit before resolving so the query lands immediately on the names that
    // are already known. Remote matches belong to the previous query, so they
    // are dropped rather than carried over.
    emit(
      state.copyWith(
        query: query,
        candidatePubkeys: event.candidatePubkeys,
        remoteMatches: const {},
      ),
    );

    // Server-side first: one request, and the only side that can match a
    // profile this device has never cached.
    await _searchRemotely(emit, query: query);
    await _resolveSearchTerms(emit);
  }

  /// Ask the API which members of this list match [query].
  ///
  /// Silent on failure by contract — [FollowRepository.searchFollowList]
  /// returns an empty set when the search cannot be answered, and the
  /// on-device pass below still runs.
  Future<void> _searchRemotely(
    Emitter<FollowListSearchState> emit, {
    required String query,
  }) async {
    if (query.isEmpty || _subjectPubkey.isEmpty) return;

    final matches = await _followRepository.searchFollowList(
      pubkey: _subjectPubkey,
      query: query,
      kind: _listKind,
    );

    if (matches.isEmpty || emit.isDone) return;
    // Guard against a slow response landing after the user retyped.
    if (state.query != query) return;
    emit(state.copyWith(remoteMatches: matches));
  }

  Future<void> _onProfileRepositoryChanged(
    FollowListSearchProfileRepositoryChanged event,
    Emitter<FollowListSearchState> emit,
  ) async {
    if (identical(event.repository, _profileRepository)) return;
    _profileRepository = event.repository;
    // A query typed before the repository resolved matched on fallback names
    // only; complete it now that real profiles are reachable.
    await _resolveSearchTerms(emit);
  }

  /// Fill [FollowListSearchState.searchTerms] for candidates that have none.
  ///
  /// No-ops unless a query is active, so an untouched search field never
  /// triggers profile traffic.
  Future<void> _resolveSearchTerms(Emitter<FollowListSearchState> emit) async {
    final repository = _profileRepository;
    if (state.query.isEmpty || repository == null) return;

    var searchTerms = state.searchTerms;
    final unresolved = state.candidatePubkeys
        .where((pubkey) => !searchTerms.containsKey(pubkey))
        .toSet()
        .toList();

    for (var i = 0; i < unresolved.length; i += searchProfileResolveChunkSize) {
      if (emit.isDone) return;
      final chunk = unresolved
          .skip(i)
          .take(searchProfileResolveChunkSize)
          .toList();

      var fetched = const <String, UserProfile>{};
      try {
        fetched = await repository.fetchBatchProfiles(pubkeys: chunk);
      } catch (error, stackTrace) {
        // Expected offline and on relay timeouts. The chunk falls back to
        // generated names below, which is what the tiles render anyway.
        addError(error, stackTrace);
      }

      searchTerms = {
        ...searchTerms,
        for (final pubkey in chunk)
          pubkey: _searchTermFor(pubkey, fetched[pubkey]),
      };

      if (emit.isDone) return;
      emit(state.copyWith(searchTerms: searchTerms));
    }
  }

  /// The lowercased haystack matched against the query for one user.
  static String _searchTermFor(String pubkey, UserProfile? profile) {
    if (profile == null) {
      return UserProfile.defaultDisplayNameFor(pubkey).toLowerCase();
    }
    return '${profile.bestDisplayName} ${profile.handle}'.trim().toLowerCase();
  }
}
