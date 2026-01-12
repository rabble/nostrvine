// ABOUTME: State class for MyVideosCountBloc
// ABOUTME: Represents the video count state for current user's profile

part of 'my_videos_count_bloc.dart';

/// Enum representing the status of video count loading
enum MyVideosCountStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading count
  loading,

  /// Count loaded successfully
  success,

  /// An error occurred while loading count
  failure,
}

/// State class for MyVideosCountBloc
final class MyVideosCountState extends Equatable {
  const MyVideosCountState({
    this.status = MyVideosCountStatus.initial,
    this.count = 0,
  });

  /// The current status of video count loading
  final MyVideosCountStatus status;

  /// The video count for the current user
  final int count;

  /// Create a copy with updated values
  MyVideosCountState copyWith({
    MyVideosCountStatus? status,
    int? count,
  }) {
    return MyVideosCountState(
      status: status ?? this.status,
      count: count ?? this.count,
    );
  }

  @override
  List<Object?> get props => [status, count];
}
