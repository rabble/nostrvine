import 'package:nostr_apps/nostr_apps.dart' as integrated_apps;
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/nostr_app_audit_service.dart';
import 'package:openvine/services/nostr_app_bridge_policy.dart';

export 'package:nostr_apps/nostr_apps.dart'
    show BridgePermissionPrompter, BridgePermissionRequest, BridgeResult;

typedef NostrAppSignerFactory = NostrSigner Function(AuthService authService);

class NostrAppBridgeService {
  NostrAppBridgeService({
    required AuthService authService,
    required NostrAppBridgePolicy policy,
    NostrAppSignerFactory? signerFactory,
    NostrAppAuditService? auditService,
  }) : _delegate = integrated_apps.NostrAppBridgeService(
         bridgeGateway: _AuthServiceNostrAppBridgeGateway(
           authService: authService,
           signerFactory:
               signerFactory ??
               ((service) =>
                   service.rpcSigner ??
                   AuthServiceSigner(service.currentKeyContainer)),
         ),
         policy: policy,
         auditService: auditService?.implementation,
       );

  final integrated_apps.NostrAppBridgeService _delegate;

  Future<integrated_apps.BridgeResult> handleRequest({
    required NostrAppDirectoryEntry app,
    required Uri origin,
    required String method,
    required Map<String, dynamic> args,
    integrated_apps.BridgePermissionPrompter? promptForPermission,
  }) {
    return _delegate.handleRequest(
      app: app,
      origin: origin,
      method: method,
      args: args,
      promptForPermission: promptForPermission,
    );
  }
}

class _AuthServiceNostrAppBridgeGateway
    implements integrated_apps.NostrAppBridgeGateway {
  _AuthServiceNostrAppBridgeGateway({
    required AuthService authService,
    required NostrAppSignerFactory signerFactory,
  }) : _authService = authService,
       _signerFactory = signerFactory;

  final AuthService _authService;
  final NostrAppSignerFactory _signerFactory;

  @override
  String? get currentPublicKeyHex => _authService.currentPublicKeyHex;

  @override
  List<integrated_apps.NostrAppRelay> get userRelays => _authService.userRelays
      .map(
        (relay) => integrated_apps.NostrAppRelay(
          url: relay.url,
          read: relay.read,
          write: relay.write,
        ),
      )
      .toList(growable: false);

  @override
  Future<Map<dynamic, dynamic>?> getFallbackRelays() async {
    return _signerFactory(_authService).getRelays();
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) {
    return _signerFactory(_authService).nip44Decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) {
    return _signerFactory(_authService).nip44Encrypt(pubkey, plaintext);
  }

  @override
  Future<Map<String, dynamic>?> signEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final signedEvent = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );
    return signedEvent?.toJson();
  }
}
