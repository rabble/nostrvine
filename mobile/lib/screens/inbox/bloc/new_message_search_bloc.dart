// ABOUTME: BLoC for the new message recipient search sheet.
// ABOUTME: Loads followed contacts and merges them with network search results.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'new_message_search_event.dart';
part 'new_message_search_state.dart';

/// BLoC for the new message sheet that loads followed contacts and searches
/// for users to start a DM conversation.
class NewMessageSearchBloc
    extends Bloc<NewMessageSearchEvent, NewMessageSearchState> {
  NewMessageSearchBloc({
    required ProfileRepository profileRepository,
    required FollowRepository followRepository,
    required String currentUserPubkey,
  }) : _profileRepository = profileRepository,
       _followRepository = followRepository,
       _currentUserPubkey = currentUserPubkey,
       super(const NewMessageSearchState()) {
    on<NewMessageSearchStarted>(_onStarted);
    on<NewMessageSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<NewMessageSearchCleared>(_onCleared);
    on<NewMessageSearchPeerLabelsChanged>(_onPeerLabelsChanged);
    on<_NewMessageSearchVanishedPubkeysChanged>(_onVanishedPubkeysChanged);
    _subscribeToVanishedPubkeys();
  }

  final ProfileRepository _profileRepository;
  final FollowRepository _followRepository;
  final String _currentUserPubkey;

  /// Live mirror of the durable `vanished_profiles` table.
  StreamSubscription<Set<String>>? _vanishedSubscription;

  Future<void> _onStarted(
    NewMessageSearchStarted event,
    Emitter<NewMessageSearchState> emit,
  ) async {
    final pubkeys = _followRepository.followingPubkeys.where(
      (pubkey) => !_isSelf(pubkey),
    );
    final futures = pubkeys.map(
      (pk) => _profileRepository.getCachedProfile(pubkey: pk),
    );
    final results = await Future.wait(futures);
    // Ordered by the name the row renders, not the raw kind-0 one: a vanished
    // peer sorts under "Deleted account" and the moderation account under
    // "Divine Moderation", so the alphabetical run matches what is on screen.
    final profiles = _sortedByPeerName(
      results.whereType<UserProfile>().toList(),
      vanishedPubkeys: state.vanishedPubkeys,
      labels: state.peerLabels,
    );

    emit(
      state.copyWith(status: NewMessageSearchStatus.idle, contacts: profiles),
    );
  }

  Future<void> _onQueryChanged(
    NewMessageSearchQueryChanged event,
    Emitter<NewMessageSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(
        state.copyWith(
          status: NewMessageSearchStatus.idle,
          query: '',
          results: const [],
        ),
      );
      return;
    }

    // Filter contacts locally for immediate display
    final filtered = _filterContacts(state.contacts, query);

    emit(
      state.copyWith(
        status: NewMessageSearchStatus.searching,
        query: query,
        results: filtered,
      ),
    );

    try {
      final networkResults = (await _profileRepository.searchUsers(
        query: query,
        limit: 50,
        sortBy: profileSearchSortFollowers,
      )).where((profile) => !_isSelf(profile.pubkey)).toList();

      Log.debug(
        'Query "$query": ${networkResults.length} network results',
        name: 'NewMessageSearchBloc',
        category: LogCategory.api,
      );

      final merged = _mergeWithLocal(networkResults, filtered);

      emit(
        state.copyWith(
          status: NewMessageSearchStatus.searchSuccess,
          results: merged,
        ),
      );
    } on Exception {
      // On failure, keep the filtered local contacts visible
      emit(state.copyWith(status: NewMessageSearchStatus.searchFailure));
    }
  }

  void _onCleared(
    NewMessageSearchCleared event,
    Emitter<NewMessageSearchState> emit,
  ) {
    emit(
      state.copyWith(
        status: NewMessageSearchStatus.idle,
        query: '',
        results: const [],
      ),
    );
  }

  /// Whether [pubkey] addresses the viewer.
  ///
  /// Divine does not support a self-addressed conversation (#8351, decided
  /// on #8261), so the viewer is never a candidate recipient. Filtered here in
  /// the picker rather than in the follow list: a contact list written by
  /// another Nostr client can legitimately self-follow, and only the merge
  /// path strips that — every other path assigns the list as received.
  ///
  /// Case-insensitive, because a pubkey that reaches Divine from another
  /// client may be upper-case hex.
  bool _isSelf(String pubkey) => pubkeysEqual(pubkey, _currentUserPubkey);

  /// Filters contacts by the name the row renders, or by NIP-05.
  ///
  /// Matching the raw `bestDisplayName` is the defect #8204 fixed in
  /// `ConversationListBloc`: it lets a row be found by a string it does not
  /// show — a vanished peer surfacing under a generated "Adjective Animal N"
  /// the viewer has never seen — and hides it from the name it does show.
  List<UserProfile> _filterContacts(List<UserProfile> contacts, String query) {
    final lower = query.toLowerCase();
    return contacts.where((profile) {
      final name = _peerName(profile).toLowerCase();
      final nip05 = (profile.nip05 ?? '').toLowerCase();
      return name.contains(lower) || nip05.contains(lower);
    }).toList();
  }

  /// The name `_UserTile` renders for [profile], resolved the same way.
  ///
  /// Takes its inputs rather than reading `state`, so an ordering can be
  /// recomputed against a state that has not been emitted yet.
  ///
  /// Falls back to the profile-or-generated value while [labels] is null,
  /// which is the pre-delivery window only.
  static String _peerNameFor(
    UserProfile profile, {
    required Set<String> vanishedPubkeys,
    required DmPeerLabels? labels,
  }) {
    if (labels == null) return profile.bestDisplayName;
    return dmPeerName(
      pubkeyHex: profile.pubkey,
      isVanished: vanishedPubkeys.contains(profile.pubkey),
      isModeration: isModerationAccount(profile.pubkey),
      labels: labels,
      profileName: profile.bestDisplayName,
    );
  }

  /// [contacts] ordered by the name each row renders.
  static List<UserProfile> _sortedByPeerName(
    List<UserProfile> contacts, {
    required Set<String> vanishedPubkeys,
    required DmPeerLabels? labels,
  }) {
    String key(UserProfile p) => _peerNameFor(
      p,
      vanishedPubkeys: vanishedPubkeys,
      labels: labels,
    ).toLowerCase();
    return contacts.toList()..sort((a, b) => key(a).compareTo(key(b)));
  }

  /// The name `_UserTile` renders for [profile], against the current state.
  String _peerName(UserProfile profile) => _peerNameFor(
    profile,
    vanishedPubkeys: state.vanishedPubkeys,
    labels: state.peerLabels,
  );

  /// (Re)points the vanished-set subscription at the profile repository.
  void _subscribeToVanishedPubkeys() {
    _vanishedSubscription = _profileRepository.watchVanishedPubkeys().listen(
      // A stream callback resumes outside the handler that started it, so the
      // add has to be guarded — `close()` does not cancel it.
      (pubkeys) => addIfOpen(_NewMessageSearchVanishedPubkeysChanged(pubkeys)),
      onError: (Object error, StackTrace stackTrace) {
        // Drift / IO failures are expected here and are not Reportable.
        addError(error, stackTrace);
      },
    );
  }

  void _onVanishedPubkeysChanged(
    _NewMessageSearchVanishedPubkeysChanged event,
    Emitter<NewMessageSearchState> emit,
  ) {
    if (event.pubkeys.length == state.vanishedPubkeys.length &&
        event.pubkeys.containsAll(state.vanishedPubkeys)) {
      return;
    }
    emit(
      state.copyWith(
        vanishedPubkeys: event.pubkeys,
        // Both inputs land asynchronously — the tombstone stream on its first
        // Drift emission, the labels on the first didChangeDependencies — and
        // either can arrive after the contact list is already sorted. Without
        // this the order stays keyed on the raw names.
        contacts: _sortedByPeerName(
          state.contacts,
          vanishedPubkeys: event.pubkeys,
          labels: state.peerLabels,
        ),
      ),
    );
  }

  void _onPeerLabelsChanged(
    NewMessageSearchPeerLabelsChanged event,
    Emitter<NewMessageSearchState> emit,
  ) {
    if (event.labels == state.peerLabels) return;
    emit(
      state.copyWith(
        peerLabels: event.labels,
        contacts: _sortedByPeerName(
          state.contacts,
          vanishedPubkeys: state.vanishedPubkeys,
          labels: event.labels,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    unawaited(_vanishedSubscription?.cancel());
    return super.close();
  }

  /// Merges network results with local contacts, deduplicating by pubkey.
  /// Network results take precedence; local contacts fill gaps.
  static List<UserProfile> _mergeWithLocal(
    List<UserProfile> networkResults,
    List<UserProfile> localContacts,
  ) {
    if (localContacts.isEmpty) return networkResults;
    if (networkResults.isEmpty) return localContacts;

    final merged = <String, UserProfile>{};
    for (final profile in networkResults) {
      merged[profile.pubkey] = profile;
    }
    for (final profile in localContacts) {
      merged.putIfAbsent(profile.pubkey, () => profile);
    }
    return merged.values.toList();
  }
}
