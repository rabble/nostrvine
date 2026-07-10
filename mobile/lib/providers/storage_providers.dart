// ABOUTME: Riverpod provider for the settings "Storage" screen service.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Provides the [StorageManagementService], wired to the app's download caches
/// and the current account's clip library. Rebuilds when the account changes
/// so the library audit stays scoped to the signed-in user.
final storageManagementServiceProvider = Provider<StorageManagementService>(
  (ref) {
    final uploadManager = ref.watch(uploadManagerProvider);
    return StorageManagementService(
      videoCache: openVineMediaCache,
      imageCache: openVineImageCache,
      clipLibrary: ref.watch(clipLibraryServiceProvider),
      prefs: ref.watch(sharedPreferencesProvider),
      protectedTempRenderPaths: () => {
        for (final upload in uploadManager.pendingUploads)
          if (upload.status != UploadStatus.published) upload.localVideoPath,
      },
    );
  },
);
