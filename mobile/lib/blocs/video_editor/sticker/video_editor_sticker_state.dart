part of 'video_editor_sticker_bloc.dart';

/// State for video editor sticker bloc.
sealed class VideoEditorStickerState extends Equatable {
  const VideoEditorStickerState();

  @override
  List<Object?> get props => [];
}

/// Initial state before stickers are loaded.
class VideoEditorStickerInitial extends VideoEditorStickerState {
  const VideoEditorStickerInitial();
}

/// Stickers are being loaded.
class VideoEditorStickerLoading extends VideoEditorStickerState {
  const VideoEditorStickerLoading();
}

/// Stickers loaded successfully.
class VideoEditorStickerLoaded extends VideoEditorStickerState {
  const VideoEditorStickerLoaded({
    required this.stickers,
    this.searchQuery = '',
  });

  /// The list of stickers to display (filtered if search is active).
  final List<StickerData> stickers;

  /// The current search query, empty if no search is active.
  final String searchQuery;

  bool get hasSearchQuery => searchQuery.isNotEmpty;

  bool get isEmpty => stickers.isEmpty;

  @override
  List<Object?> get props => [stickers, searchQuery];
}

/// Error loading stickers.
class VideoEditorStickerError extends VideoEditorStickerState {
  const VideoEditorStickerError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
