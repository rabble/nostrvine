// ABOUTME: State classes for the StickerPickerBloc
// ABOUTME: Sealed state hierarchy for loading, loaded, and error states

part of 'sticker_picker_bloc.dart';

/// Typed error categories for the sticker picker.
enum StickerPickerErrorType { loadFailed }

/// Base state for the sticker picker.
sealed class StickerPickerState extends Equatable {
  const StickerPickerState();
}

/// Initial state before any loading.
final class StickerPickerInitial extends StickerPickerState {
  const StickerPickerInitial();

  @override
  List<Object> get props => [];
}

/// Loading sticker packs from relays.
final class StickerPickerLoading extends StickerPickerState {
  const StickerPickerLoading();

  @override
  List<Object> get props => [];
}

/// Sticker packs loaded successfully.
final class StickerPickerLoaded extends StickerPickerState {
  const StickerPickerLoaded({
    required this.packs,
    required this.allStickers,
    required this.filteredStickers,
    this.searchQuery = '',
  });

  /// All loaded sticker packs.
  final List<StickerPack> packs;

  /// All stickers flattened from all packs (computed once on load).
  final List<Sticker> allStickers;

  /// Flat list of stickers matching the current search query.
  /// When search is empty, contains all stickers from all packs.
  final List<Sticker> filteredStickers;

  /// Current search query.
  final String searchQuery;

  @override
  List<Object> get props => [packs, allStickers, filteredStickers, searchQuery];
}

/// Error loading sticker packs.
final class StickerPickerError extends StickerPickerState {
  const StickerPickerError(this.errorType);

  /// The type of error that occurred.
  final StickerPickerErrorType errorType;

  @override
  List<Object> get props => [errorType];
}
