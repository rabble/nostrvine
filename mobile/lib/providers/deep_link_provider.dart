// ABOUTME: Riverpod provider for deep link handling service
// ABOUTME: Manages app-wide universal/deep link routing

import 'package:openvine/services/deep_link_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deep_link_provider.g.dart';

/// Provider for the deep link service
/// Note: Does NOT auto-initialize - caller must call initialize() after setting up listeners
@Riverpod(keepAlive: true)
DeepLinkService deepLinkService(Ref ref) {
  final service = DeepLinkService();
  // Don't initialize here - it will be done after listener is set up
  ref.onDispose(service.dispose);
  return service;
}

/// Stream provider for incoming deep links
@riverpod
Stream<DeepLink> deepLinks(Ref ref) {
  final service = ref.watch(deepLinkServiceProvider);
  return service.linkStream;
}
