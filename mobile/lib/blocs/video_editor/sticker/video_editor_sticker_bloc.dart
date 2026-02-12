import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/utils/unified_logger.dart';

part 'video_editor_sticker_event.dart';
part 'video_editor_sticker_state.dart';

/// BLoC for managing sticker selection in the video editor.
///
/// Handles:
/// - Loading stickers from assets
/// - Filtering stickers by search query
class VideoEditorStickerBloc
    extends Bloc<VideoEditorStickerEvent, VideoEditorStickerState> {
  VideoEditorStickerBloc({required this.onPrecacheStickers})
    : super(const VideoEditorStickerInitial()) {
    on<VideoEditorStickerLoad>(_onLoad);
    on<VideoEditorStickerSearch>(_onSearch);
  }

  /// Maximum number of stickers to precache on initial load.
  static const maxPrecacheCount = 18;

  List<StickerData> _allStickers = [];

  /// Called after stickers are loaded for precaching.
  final Function(List<StickerData> stickers) onPrecacheStickers;

  Future<void> _onLoad(
    VideoEditorStickerLoad event,
    Emitter<VideoEditorStickerState> emit,
  ) async {
    emit(const VideoEditorStickerLoading());

    try {
      // Load stickers from JSON to support shareable sticker packs in the
      // future.
      final jsonString = await rootBundle.loadString(
        'assets/stickers/stickers.json',
      );
      final jsonList = json.decode(jsonString) as List<dynamic>;

      _allStickers = jsonList
          .map((e) => StickerData.fromJson(e as Map<String, dynamic>))
          .toList();

      Log.debug(
        '🌟 Loaded ${_allStickers.length} stickers',
        name: 'VideoEditorStickerBloc',
        category: LogCategory.video,
      );

      emit(VideoEditorStickerLoaded(stickers: _allStickers));
      onPrecacheStickers(_allStickers.take(maxPrecacheCount).toList());
    } catch (e) {
      Log.error(
        '🌟 Failed to load stickers: $e',
        name: 'VideoEditorStickerBloc',
        category: LogCategory.video,
      );
      emit(VideoEditorStickerError(e.toString()));
    }
  }

  void _onSearch(
    VideoEditorStickerSearch event,
    Emitter<VideoEditorStickerState> emit,
  ) {
    final query = event.query.trim().toLowerCase();

    if (query.isEmpty) {
      emit(VideoEditorStickerLoaded(stickers: _allStickers));
      return;
    }

    final filtered = _allStickers.where((sticker) {
      final description = sticker.description.toLowerCase();
      final tags = sticker.tags.map((t) => t.toLowerCase()).toList();

      return description.contains(query) ||
          tags.any((tag) => tag.contains(query));
    }).toList();

    emit(VideoEditorStickerLoaded(stickers: filtered, searchQuery: query));
  }
}
