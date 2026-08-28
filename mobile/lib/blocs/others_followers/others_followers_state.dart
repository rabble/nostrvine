// ABOUTME: State class for OthersFollowersBloc
// ABOUTME: Represents all possible states of another user's followers list

part of 'others_followers_bloc.dart';

/// Enum representing the status of the followers list loading
enum OthersFollowersStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data from Nostr
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for OthersFollowersBloc
final class OthersFollowersState extends Equatable {
  const OthersFollowersState({
    this.status = OthersFollowersStatus.initial,
    this.followersPubkeys = const [],
    this.rawFollowersPubkeys = const [],
    this.authoritativeFollowerCount = 0,
    this.targetPubkey,
    this.isRefreshing = false,
    this.isFollowingTarget = false,
  });

  /// The current status of the followers list
  final OthersFollowersStatus status;

  /// List of pubkeys who follow the target user (blocklist-filtered).
  final List<String> followersPubkeys;

  /// Unfiltered follower pubkeys as received from the repository.
  ///
  /// Stored in state so blocklist re-filtering and optimistic updates can
  /// replay the full list without waiting for a new network event.
  final List<String> rawFollowersPubkeys;

  /// Follower count as reported by the repository, before local safety filters.
  ///
  /// Kept separately so blocklist changes can recompute [followerCount] from
  /// the raw list without losing the server-provided baseline.
  final int authoritativeFollowerCount;

  /// Follower count shown in the UI after applying known local safety filters.
  ///
  /// Funnelcake remains the deterministic baseline (#8197), but accounts
  /// hidden by the viewer's safety state must not still appear in the count
  /// beside the filtered list. Only hidden rows actually observed in the
  /// fetched list are subtracted; the result is not floored at the
  /// relay-derived visible row count, so relay coverage cannot inflate or
  /// destabilize the displayed number.
  int get followerCount => visibleFollowerCount(
    visiblePubkeyCount: followersPubkeys.length,
    rawPubkeyCount: rawFollowersPubkeys.length,
    authoritativeFollowerCount: authoritativeFollowerCount,
  );

  /// The pubkey whose followers list is being viewed (for retry)
  final String? targetPubkey;

  /// Whether a background refresh is in progress (stale-while-revalidate).
  ///
  /// When [true], the list is showing cached data while fresh data loads.
  /// Used by the UI to show a progress indicator via [LoadingOverlay].
  final bool isRefreshing;

  /// Whether the current user follows the target user.
  ///
  /// Used to decide whether to hide the current user from the target's
  /// follower list (a user who doesn't follow back is hidden).
  final bool isFollowingTarget;

  /// Create a copy with updated values
  OthersFollowersState copyWith({
    OthersFollowersStatus? status,
    List<String>? followersPubkeys,
    List<String>? rawFollowersPubkeys,
    int? authoritativeFollowerCount,
    String? targetPubkey,
    bool? isRefreshing,
    bool? isFollowingTarget,
  }) {
    return OthersFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      rawFollowersPubkeys: rawFollowersPubkeys ?? this.rawFollowersPubkeys,
      authoritativeFollowerCount:
          authoritativeFollowerCount ?? this.authoritativeFollowerCount,
      targetPubkey: targetPubkey ?? this.targetPubkey,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isFollowingTarget: isFollowingTarget ?? this.isFollowingTarget,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followersPubkeys,
    rawFollowersPubkeys,
    authoritativeFollowerCount,
    targetPubkey,
    isRefreshing,
    isFollowingTarget,
  ];
}
