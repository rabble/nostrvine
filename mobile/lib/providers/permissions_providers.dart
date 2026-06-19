// ABOUTME: Permission / geo-blocking / gallery-save providers split from
// ABOUTME: app_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permissions_providers.g.dart';

/// Geo-blocking service for regional compliance
@riverpod
GeoBlockingService geoBlockingService(Ref ref) {
  return GeoBlockingService();
}

/// Permissions service for checking and requesting OS permissions
final permissionsServiceProvider = Provider<PermissionsService>(
  (_) => const PermissionHandlerPermissionsService(),
  name: 'permissionsServiceProvider',
);

/// Gallery save service for saving videos to device camera roll
@riverpod
GallerySaveService gallerySaveService(Ref ref) {
  return GallerySaveService(
    permissionsService: ref.watch(permissionsServiceProvider),
  );
}
