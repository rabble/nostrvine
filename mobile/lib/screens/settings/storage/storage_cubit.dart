import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/storage_management_service.dart';

part 'storage_state.dart';

/// Drives the settings "Storage" screen: reports the clearable cache size,
/// clears it on demand, and audits the clip library for broken entries.
class StorageCubit extends Cubit<StorageState> {
  /// Creates a cubit backed by [service] and loads the current cache size.
  StorageCubit({required StorageManagementService service})
    : _service = service,
      super(const StorageState());

  final StorageManagementService _service;

  /// Loads the current clearable cache size.
  Future<void> loadCacheSize() async {
    emit(state.copyWith(cacheStatus: StorageCacheStatus.loading));
    try {
      final bytes = await _service.cacheSizeBytes();
      emit(
        state.copyWith(
          cacheStatus: StorageCacheStatus.ready,
          cacheSizeBytes: bytes,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(cacheStatus: StorageCacheStatus.failure));
    }
  }

  /// Clears the caches, then refreshes the reported size.
  Future<void> clearCaches() async {
    emit(state.copyWith(cacheStatus: StorageCacheStatus.clearing));
    try {
      await _service.clearCaches();
      final bytes = await _service.cacheSizeBytes();
      emit(
        state.copyWith(
          cacheStatus: StorageCacheStatus.ready,
          cacheSizeBytes: bytes,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(cacheStatus: StorageCacheStatus.failure));
    }
  }

  /// Scans the clip library for clips whose backing file is missing.
  Future<void> scanLibrary() async {
    emit(state.copyWith(libraryStatus: StorageLibraryStatus.scanning));
    try {
      final broken = await _service.findBrokenClips();
      emit(
        state.copyWith(
          libraryStatus: StorageLibraryStatus.scanned,
          brokenClips: broken,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(libraryStatus: StorageLibraryStatus.failure));
    }
  }

  /// Removes the broken clips found by [scanLibrary].
  Future<void> removeBrokenClips() async {
    if (state.brokenClips.isEmpty) return;
    emit(state.copyWith(libraryStatus: StorageLibraryStatus.cleaning));
    try {
      await _service.removeBrokenClips(state.brokenClips);
      emit(
        state.copyWith(
          libraryStatus: StorageLibraryStatus.cleaned,
          brokenClips: const [],
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(libraryStatus: StorageLibraryStatus.failure));
    }
  }
}
