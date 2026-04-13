// ABOUTME: State for the ProfileCommentsBloc.
// ABOUTME: Maintains separate lists for video replies and text comments,
// ABOUTME: with pagination support via createdAt cursor.

part of 'profile_comments_bloc.dart';

/// Status of the profile comments loading.
enum ProfileCommentsStatus {
  /// Initial state before any data has been requested.
  initial,

  /// Comments are being loaded for the first time.
  loading,

  /// Comments have been loaded successfully.
  success,

  /// Loading comments failed.
  failure,
}

/// State containing a user's comments split into video replies and text.
final class ProfileCommentsState extends Equatable {
  /// Creates a new profile comments state.
  const ProfileCommentsState({
    this.status = ProfileCommentsStatus.initial,
    this.videoReplies = const [],
    this.textComments = const [],
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.paginationCursor,
  });

  /// Current loading status.
  final ProfileCommentsStatus status;

  /// Comments that have attached video (hasVideo == true).
  final List<Comment> videoReplies;

  /// Comments that are text-only (hasVideo == false).
  final List<Comment> textComments;

  /// Whether more comments are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more comments to load.
  final bool hasMoreContent;

  /// Pagination cursor — the createdAt of the oldest loaded comment.
  final DateTime? paginationCursor;

  /// Whether comments have been loaded successfully.
  bool get isLoaded => status == ProfileCommentsStatus.success;

  /// Whether comments are currently loading.
  bool get isLoading => status == ProfileCommentsStatus.loading;

  /// Total number of comments (video + text).
  int get totalCount => videoReplies.length + textComments.length;

  /// Creates a copy with updated fields.
  ProfileCommentsState copyWith({
    ProfileCommentsStatus? status,
    List<Comment>? videoReplies,
    List<Comment>? textComments,
    bool? isLoadingMore,
    bool? hasMoreContent,
    DateTime? paginationCursor,
  }) {
    return ProfileCommentsState(
      status: status ?? this.status,
      videoReplies: videoReplies ?? this.videoReplies,
      textComments: textComments ?? this.textComments,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      paginationCursor: paginationCursor ?? this.paginationCursor,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videoReplies,
    textComments,
    isLoadingMore,
    hasMoreContent,
    paginationCursor,
  ];
}
