// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

typedef CrosspostingApiClientFactory =
    CrosspostingApiClient Function(
      KeycastOAuth oauthClient,
    );

final crosspostingApiClientFactoryProvider =
    Provider<CrosspostingApiClientFactory>((ref) {
      return (oauthClient) => CrosspostingApiClient(oauthClient: oauthClient);
    });

final crosspostingApiClientProvider = Provider<CrosspostingApiClient>((ref) {
  final oauthClient = ref.watch(oauthClientProvider);
  final createClient = ref.watch(crosspostingApiClientFactoryProvider);
  final client = createClient(oauthClient);
  ref.onDispose(client.close);
  return client;
});

final crosspostingRepositoryProvider = Provider<CrosspostingRepository>((ref) {
  return CrosspostingRepository(ref.watch(crosspostingApiClientProvider));
});
