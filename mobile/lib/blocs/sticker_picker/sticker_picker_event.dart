// ABOUTME: Events for the StickerPickerBloc
// ABOUTME: Defines actions for loading sticker packs and searching stickers

part of 'sticker_picker_bloc.dart';

/// Base class for all sticker picker events.
sealed class StickerPickerEvent {
  const StickerPickerEvent();
}

/// Request to load sticker packs from relays.
final class StickerPacksLoadRequested extends StickerPickerEvent {
  const StickerPacksLoadRequested();
}

/// Search query changed for filtering stickers by shortcode.
final class StickerSearchChanged extends StickerPickerEvent {
  const StickerSearchChanged(this.query);

  /// The search query string.
  final String query;
}
