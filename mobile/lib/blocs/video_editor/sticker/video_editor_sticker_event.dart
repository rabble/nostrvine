part of 'video_editor_sticker_bloc.dart';

/// Base event for video editor sticker actions.
sealed class VideoEditorStickerEvent extends Equatable {
  const VideoEditorStickerEvent();

  @override
  List<Object?> get props => [];
}

/// Load stickers from assets.
class VideoEditorStickerLoad extends VideoEditorStickerEvent {
  const VideoEditorStickerLoad();
}

/// Search/filter stickers by query.
class VideoEditorStickerSearch extends VideoEditorStickerEvent {
  const VideoEditorStickerSearch(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
