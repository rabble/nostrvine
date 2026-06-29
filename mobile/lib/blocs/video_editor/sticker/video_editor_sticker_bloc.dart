import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/sticker_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_editor_sticker_event.dart';
part 'video_editor_sticker_state.dart';

/// BLoC for managing sticker selection in the video editor.
///
/// Handles:
/// - Loading stickers from the repository
/// - Filtering stickers by search query
class VideoEditorStickerBloc
    extends Bloc<VideoEditorStickerEvent, VideoEditorStickerState> {
  VideoEditorStickerBloc({
    required this.stickerRepository,
    required this.onPrecacheStickers,
  }) : super(const VideoEditorStickerInitial()) {
    on<VideoEditorStickerLoad>(_onLoad);
    on<VideoEditorStickerSearch>(_onSearch);
  }

  /// Maximum number of stickers to precache on initial load.
  static const maxPrecacheCount = 18;

  /// Loads the sticker catalog from bundled assets.
  final StickerRepository stickerRepository;

  /// Called after stickers are loaded for precaching.
  final Function(List<StickerData> stickers) onPrecacheStickers;

  Future<void> _onLoad(
    VideoEditorStickerLoad event,
    Emitter<VideoEditorStickerState> emit,
  ) async {
    emit(const VideoEditorStickerLoading());

    try {
      final stickers = await stickerRepository.loadStickers(event.localeCode);

      Log.debug(
        '🌟 Loaded ${stickers.length} stickers',
        name: 'VideoEditorStickerBloc',
        category: LogCategory.video,
      );

      emit(VideoEditorStickerLoaded(stickers: stickers, allStickers: stickers));
      onPrecacheStickers(stickers.take(maxPrecacheCount).toList());
    } catch (e, stackTrace) {
      // Matrix-YES: every failure path here is a build/asset invariant —
      // missing bundled asset (FlutterError), corrupt JSON (FormatException),
      // or shape-mismatch cast (TypeError). Bundled assets ship inside the
      // IPA/APK so runtime PlatformException is essentially impossible.
      addError(Reportable(e, context: '_onLoad'), stackTrace);
      Log.error(
        '🌟 Failed to load stickers: $e',
        name: 'VideoEditorStickerBloc',
        category: LogCategory.video,
      );
      emit(const VideoEditorStickerError());
    }
  }

  void _onSearch(
    VideoEditorStickerSearch event,
    Emitter<VideoEditorStickerState> emit,
  ) {
    final currentState = state;
    if (currentState is! VideoEditorStickerLoaded) return;

    final allStickers = currentState.allStickers;
    final query = event.query.trim().toLowerCase();

    if (query.isEmpty) {
      emit(
        VideoEditorStickerLoaded(
          stickers: allStickers,
          allStickers: allStickers,
        ),
      );
      return;
    }

    final filtered = allStickers.where((sticker) {
      // Match across every localized description so a sticker is findable
      // regardless of the user's locale (and by its English search keywords).
      final descriptions = sticker.description.values.values.map(
        (value) => value.toLowerCase(),
      );
      final tags = sticker.tags.map((tag) => tag.toLowerCase());

      return descriptions.any((value) => value.contains(query)) ||
          tags.any((tag) => tag.contains(query));
    }).toList();

    emit(
      VideoEditorStickerLoaded(
        stickers: filtered,
        allStickers: allStickers,
        searchQuery: query,
      ),
    );
  }
}
