// ABOUTME: Riverpod providers for invite gate configuration and approval state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/invite_api_service.dart';

final inviteApiServiceProvider = Provider<InviteApiService>((ref) {
  final authService = ref.watch(nip98AuthServiceProvider);
  final service = InviteApiService(authService: authService);
  ref.onDispose(service.dispose);
  return service;
});

final inviteClientConfigProvider = FutureProvider<InviteClientConfig>((
  ref,
) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.getClientConfig();
});

final inviteAccessGrantProvider =
    NotifierProvider<InviteAccessGrantNotifier, InviteAccessGrant?>(
      InviteAccessGrantNotifier.new,
    );

class InviteAccessGrantNotifier extends Notifier<InviteAccessGrant?> {
  @override
  InviteAccessGrant? build() => null;

  void grant(InviteAccessGrant value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}
