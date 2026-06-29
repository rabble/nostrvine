part of 'video_editor_sticker_bloc.dart';

/// Base event for video editor sticker actions.
sealed class VideoEditorStickerEvent extends Equatable {
  const VideoEditorStickerEvent();

  @override
  List<Object?> get props => [];
}

/// Load stickers from assets, resolving descriptions for [localeCode].
class VideoEditorStickerLoad extends VideoEditorStickerEvent {
  const VideoEditorStickerLoad(this.localeCode);

  /// BCP-47 language code of the active locale (e.g. `en`, `de`).
  final String localeCode;

  @override
  List<Object?> get props => [localeCode];
}

/// Search/filter stickers by query.
class VideoEditorStickerSearch extends VideoEditorStickerEvent {
  const VideoEditorStickerSearch(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
