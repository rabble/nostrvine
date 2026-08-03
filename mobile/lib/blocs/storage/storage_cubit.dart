import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/cache_recovery_service.dart';
import 'package:openvine/services/storage_management_service.dart';

part 'storage_state.dart';

/// Drives the settings "Storage" screen: reports the clearable cache size,
/// clears it on demand, audits the clip library for broken entries, and runs
/// the last-resort repair wipe for a corrupted install.
class StorageCubit extends Cubit<StorageState> {
  /// Creates a cubit backed by [service] and loads the current cache size.
  ///
  /// [recoverAllCaches] and [measureRecoveryFootprint] default to
  /// [CacheRecoveryService]'s static entry points and exist so tests can drive
  /// the repair section without touching the real filesystem.
  StorageCubit({
    required StorageManagementService service,
    Future<bool> Function() recoverAllCaches =
        CacheRecoveryService.clearAllCaches,
    Future<int> Function() measureRecoveryFootprint =
        CacheRecoveryService.cacheSizeBytes,
  }) : _service = service,
       _recoverAllCaches = recoverAllCaches,
       _measureRecoveryFootprint = measureRecoveryFootprint,
       super(const StorageState());

  final StorageManagementService _service;
  final Future<bool> Function() _recoverAllCaches;
  final Future<int> Function() _measureRecoveryFootprint;

  /// Loads the current clearable cache size and configured limit.
  Future<void> loadCacheSize() async {
    // Read the persisted limit up front — a cheap in-memory prefs read that
    // can't fail — so a size-measurement failure below still leaves the slider
    // on the user's saved budget instead of resetting it to the default.
    emit(
      state.copyWith(
        cacheStatus: StorageCacheStatus.loading,
        cacheLimitBytes: _service.cacheLimitBytes(),
      ),
    );
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

  /// Reflects a slider drag without persisting — keeps the label live while
  /// the user is still choosing.
  void previewCacheLimit(int bytes) =>
      emit(state.copyWith(cacheLimitBytes: bytes));

  /// Persists the chosen [bytes] limit, applies it, and refreshes the size
  /// (the cache may have been trimmed). Surfaces a busy status while the
  /// forced trim + re-measure runs so the stale size can't be acted on.
  Future<void> commitCacheLimit(int bytes) async {
    emit(
      state.copyWith(
        cacheStatus: StorageCacheStatus.loading,
        cacheLimitBytes: bytes,
      ),
    );
    try {
      await _service.setCacheLimit(bytes);
      final size = await _service.cacheSizeBytes();
      emit(
        state.copyWith(
          cacheStatus: StorageCacheStatus.ready,
          cacheSizeBytes: size,
          cacheLimitBytes: _service.cacheLimitBytes(),
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
          cacheStatus: StorageCacheStatus.cleared,
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

  /// Measures everything a repair wipe would clear — Hive boxes, Application
  /// Support, temp and cache directories — which is a superset of the media
  /// cache [loadCacheSize] reports.
  ///
  /// A measurement failure falls back to [StorageRecoveryStatus.idle] rather
  /// than `failure`: the size is decoration on the confirmation sheet, and
  /// `failure` is what the UI renders when the wipe itself went wrong.
  Future<void> loadRecoveryFootprint() async {
    emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.measuring));
    try {
      final footprint = await _measureRecoveryFootprint();
      emit(
        state.copyWith(
          recoveryStatus: StorageRecoveryStatus.measured,
          recoveryFootprintBytes: footprint,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.idle));
    }
  }

  /// Wipes the app's caches and databases to recover from corruption. The
  /// durable database directory is preserved by [CacheRecoveryService]; the
  /// user still has to restart the app afterwards.
  Future<void> recoverFromCorruptedCache() async {
    emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.recovering));
    try {
      final succeeded = await _recoverAllCaches();
      emit(
        state.copyWith(
          recoveryStatus: succeeded
              ? StorageRecoveryStatus.recovered
              : StorageRecoveryStatus.failure,
          recoveryFootprintBytes: 0,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(recoveryStatus: StorageRecoveryStatus.failure));
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
