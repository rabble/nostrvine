// ABOUTME: BLoC for managing sticker picker state
// ABOUTME: Handles loading sticker packs and filtering by search query

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sticker_pack_repository/sticker_pack_repository.dart';

part 'sticker_picker_event.dart';
part 'sticker_picker_state.dart';

/// BLoC for the sticker picker bottom sheet.
///
/// Handles:
/// - Loading sticker packs from [StickerPackRepository]
/// - Filtering stickers by shortcode search query
class StickerPickerBloc extends Bloc<StickerPickerEvent, StickerPickerState> {
  StickerPickerBloc({
    required StickerPackRepository stickerPackRepository,
  }) : _stickerPackRepository = stickerPackRepository,
       super(const StickerPickerInitial()) {
    on<StickerPacksLoadRequested>(_onLoadRequested);
    on<StickerSearchChanged>(_onSearchChanged, transformer: restartable());
  }

  final StickerPackRepository _stickerPackRepository;

  Future<void> _onLoadRequested(
    StickerPacksLoadRequested event,
    Emitter<StickerPickerState> emit,
  ) async {
    emit(const StickerPickerLoading());

    try {
      final packs = await _stickerPackRepository.loadStickerPacks();
      final allStickers = packs.expand((pack) => pack.stickers).toList();

      emit(
        StickerPickerLoaded(
          packs: packs,
          filteredStickers: allStickers,
        ),
      );
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(const StickerPickerError(StickerPickerErrorType.loadFailed));
    }
  }

  void _onSearchChanged(
    StickerSearchChanged event,
    Emitter<StickerPickerState> emit,
  ) {
    final currentState = state;
    if (currentState is! StickerPickerLoaded) return;

    final query = event.query.toLowerCase().trim();

    if (query.isEmpty) {
      emit(
        StickerPickerLoaded(
          packs: currentState.packs,
          filteredStickers: currentState.packs
              .expand((pack) => pack.stickers)
              .toList(),
        ),
      );
      return;
    }

    final filtered = currentState.packs
        .expand((pack) => pack.stickers)
        .where(
          (sticker) => sticker.shortcode.toLowerCase().contains(query),
        )
        .toList();

    emit(
      StickerPickerLoaded(
        packs: currentState.packs,
        filteredStickers: filtered,
        searchQuery: query,
      ),
    );
  }
}
