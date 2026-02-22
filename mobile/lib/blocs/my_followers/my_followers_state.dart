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
    this.followerCount = 0,
  });

  /// The current status of the followers list
  final MyFollowersStatus status;

  /// List of pubkeys who follow the current user
  final List<String> followersPubkeys;

  /// Authoritative follower count (max of list length and COUNT query).
  ///
  /// Downloading all kind 3 events is limited by relay result caps,
  /// so [followersPubkeys.length] may undercount. This field uses
  /// the higher of the list length and a COUNT query result.
  final int followerCount;

  /// Create a copy with updated values
  MyFollowersState copyWith({
    MyFollowersStatus? status,
    List<String>? followersPubkeys,
    int? followerCount,
  }) {
    return MyFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      followerCount: followerCount ?? this.followerCount,
    );
  }

  @override
  List<Object?> get props => [status, followersPubkeys, followerCount];
}
