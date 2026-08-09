// ABOUTME: State class for MyFollowersBloc
// ABOUTME: Represents all possible states of the current user's followers list

part of 'my_followers_bloc.dart';

/// Enum representing the status of the followers list loading
enum MyFollowersStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data from Nostr
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for MyFollowersBloc
final class MyFollowersState extends Equatable {
  const MyFollowersState({
    this.status = MyFollowersStatus.initial,
    this.followersPubkeys = const [],
    this.rawFollowersPubkeys = const [],
    this.rawDatedCount = 0,
    this.sortOrder = FollowSortOrder.newestFirst,
    this.followerCount = 0,
    this.isRefreshing = false,
  });

  /// The current status of the followers list
  final MyFollowersStatus status;

  /// List of pubkeys who follow the current user (blocklist-filtered).
  final List<String> followersPubkeys;

  /// Unfiltered follower pubkeys as received from the repository, newest
  /// follower first.
  ///
  /// Stored in state so blocklist re-filtering and sort changes can replay the
  /// full list without waiting for a new network event.
  final List<String> rawFollowersPubkeys;

  /// How many leading [rawFollowersPubkeys] carry a contact-list timestamp.
  ///
  /// Passed to [FollowSortOrder.fromNewestFirst] so [sortOrder] can flip the dated
  /// prefix while leaving undated followers at the end.
  final int rawDatedCount;

  /// The order [followersPubkeys] is presented in.
  final FollowSortOrder sortOrder;

  /// Visible follower count after applying local blocklist filters.
  ///
  /// Downloading all kind 3 events is limited by relay result caps, so this may
  /// still exceed [followersPubkeys.length]. Known blocked and follow-severed
  /// users are subtracted from the repository's authoritative count.
  final int followerCount;

  /// True while cached data is shown but a fresh network fetch is in progress.
  final bool isRefreshing;

  /// Create a copy with updated values
  MyFollowersState copyWith({
    MyFollowersStatus? status,
    List<String>? followersPubkeys,
    List<String>? rawFollowersPubkeys,
    int? rawDatedCount,
    FollowSortOrder? sortOrder,
    int? followerCount,
    bool? isRefreshing,
  }) {
    return MyFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      rawFollowersPubkeys: rawFollowersPubkeys ?? this.rawFollowersPubkeys,
      rawDatedCount: rawDatedCount ?? this.rawDatedCount,
      sortOrder: sortOrder ?? this.sortOrder,
      followerCount: followerCount ?? this.followerCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followersPubkeys,
    rawFollowersPubkeys,
    rawDatedCount,
    sortOrder,
    followerCount,
    isRefreshing,
  ];
}
