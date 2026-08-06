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
  static const _maxCompleteFollowerListSize = 5000;

  const MyFollowersState({
    this.status = MyFollowersStatus.initial,
    this.followersPubkeys = const [],
    this.rawFollowersPubkeys = const [],
    this.followerCount = 0,
    this.isRefreshing = false,
  });

  /// The current status of the followers list
  final MyFollowersStatus status;

  /// List of pubkeys who follow the current user (blocklist-filtered).
  final List<String> followersPubkeys;

  /// Unfiltered follower pubkeys as received from the repository.
  ///
  /// Stored in state so blocklist re-filtering can replay the full list
  /// without waiting for a new network event.
  final List<String> rawFollowersPubkeys;

  /// Authoritative follower count (max of list length and COUNT query).
  ///
  /// Downloading all kind 3 events is limited by relay result caps,
  /// so [followersPubkeys.length] may undercount. This field uses
  /// the higher of the list length and a COUNT query result.
  final int followerCount;

  /// True while cached data is shown but a fresh network fetch is in progress.
  final bool isRefreshing;

  /// Count to show beside the rendered follower list.
  ///
  /// [followerCount] may legitimately exceed the loaded list for very large
  /// accounts where source APIs cap follower pubkey results. For smaller lists,
  /// the loaded pubkeys are expected to be complete, so the display count stays
  /// tied to the visible rows after blocklist and follow-severed filtering.
  int get displayFollowerCount {
    final removedByFiltering =
        rawFollowersPubkeys.length - followersPubkeys.length;
    final adjustedCount = followerCount - removedByFiltering;
    if (rawFollowersPubkeys.length >= _maxCompleteFollowerListSize) {
      return adjustedCount > followersPubkeys.length
          ? adjustedCount
          : followersPubkeys.length;
    }
    return followersPubkeys.length;
  }

  /// Create a copy with updated values
  MyFollowersState copyWith({
    MyFollowersStatus? status,
    List<String>? followersPubkeys,
    List<String>? rawFollowersPubkeys,
    int? followerCount,
    bool? isRefreshing,
  }) {
    return MyFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      rawFollowersPubkeys: rawFollowersPubkeys ?? this.rawFollowersPubkeys,
      followerCount: followerCount ?? this.followerCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followersPubkeys,
    rawFollowersPubkeys,
    followerCount,
    isRefreshing,
  ];
}
