// ABOUTME: Harness for the two-device sound sync E2E test.
// ABOUTME: Wires two NostrClients to one signer and local_stack's relay.

import 'package:creator_sync/creator_sync.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/saved_sound.dart';

import '../../helpers/constants.dart';

/// Fixed 64-hex-char id both devices' copy of the test sound shares.
const String _soundId =
    'e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2';

/// Fixed 64-hex-char stand-in for the audio's creator pubkey.
///
/// Deliberately not derived from the harness's own signer: the audio
/// metadata is a fixture, not something either device publishes itself.
const String _audioPubkey =
    'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';

/// local_stack's relay, reached the same way every other
/// `mobile/integration_test/` suite reaches it.
const String _relayUrl = 'ws://$localHost:$localRelayPort';

/// One simulated device: its own sync repository, applied-state store,
/// and local sound library, plus the vault key it resolved.
typedef SyncE2eDevice = ({
  SoundSyncRepository repository,
  InMemorySyncStateStore state,
  LocalSoundStore local,
  List<int> vaultKeyBytes,
});

/// Two simulated devices on one Nostr account, wired against a real
/// local_stack relay — one signer, two independent [NostrClient]
/// connections, two independent sync repositories.
class SyncE2eHarness {
  SyncE2eHarness._({
    required this.deviceA,
    required this.deviceB,
    required NostrClient clientA,
    required NostrClient clientB,
  }) : _clientA = clientA,
       _clientB = clientB;

  /// The id shared by every [soundBody] call in a test run.
  final String soundId = _soundId;

  /// The A side of the two simulated devices.
  final SyncE2eDevice deviceA;

  /// The B side of the two simulated devices.
  final SyncE2eDevice deviceB;

  final NostrClient _clientA;
  final NostrClient _clientB;

  /// Builds a `SavedSound.toJson()` body for [soundId] with [label] as its
  /// personal label. Every other field is fixed, so tests can tell "before"
  /// and "after" edits apart by [label] alone.
  Map<String, dynamic> soundBody({required String label}) {
    return SavedSound(
      audio: const AudioEvent(
        id: _soundId,
        pubkey: _audioPubkey,
        createdAt: 1700000000,
        title: 'E2E sync sound',
      ),
      personalLabel: label,
      personalHashtags: const [],
      catalogTags: const [],
      waveformSamples: const [],
    ).toJson();
  }

  /// Generates one throwaway keypair, connects two [NostrClient]s to
  /// local_stack's relay under it, and resolves each device's vault key —
  /// device A creates and publishes it; device B unwraps it remotely
  /// because its [VaultKeyCache] starts empty.
  static Future<SyncE2eHarness> start() async {
    final privateKey = generatePrivateKey();
    final signer = LocalNostrSigner(privateKey);
    final pubkeyHex = await signer.getPublicKey();
    if (pubkeyHex == null || pubkeyHex.isEmpty) {
      throw StateError('LocalNostrSigner returned no public key');
    }

    final clientA = await _connectClient(signer);
    final clientB = await _connectClient(signer);

    final vaultKeyServiceA = VaultKeyService(
      signer: signer,
      client: clientA,
      cache: _InMemoryVaultKeyCache(),
    );
    final vaultKeyA = await vaultKeyServiceA.obtain();

    // obtain() publishes the wrapped key via publishEvent, which does not
    // await relay OK. Confirm the event is actually queryable before
    // device B tries to unwrap it — otherwise B would see "no remote key"
    // and mint a second one, permanently orphaning device A's.
    await _waitForVaultKeyEvent(clientB, pubkeyHex);

    final vaultKeyServiceB = VaultKeyService(
      signer: signer,
      client: clientB,
      // Deliberately a fresh, empty cache: this is what forces device B
      // through the remote-unwrap path instead of a local-cache hit.
      cache: _InMemoryVaultKeyCache(),
    );
    final vaultKeyB = await vaultKeyServiceB.obtain();

    final stateA = InMemorySyncStateStore();
    final localA = _InMemoryLocalSoundStore();
    final repositoryA = SoundSyncRepository(
      index: SyncIndexClient(
        client: clientA,
        signer: signer,
        cipher: SyncCipher(vaultKeyA),
      ),
      state: stateA,
      local: localA,
    );

    final stateB = InMemorySyncStateStore();
    final localB = _InMemoryLocalSoundStore();
    final repositoryB = SoundSyncRepository(
      index: SyncIndexClient(
        client: clientB,
        signer: signer,
        cipher: SyncCipher(vaultKeyB),
      ),
      state: stateB,
      local: localB,
    );

    return SyncE2eHarness._(
      deviceA: (
        repository: repositoryA,
        state: stateA,
        local: localA,
        vaultKeyBytes: await vaultKeyA.extractBytes(),
      ),
      deviceB: (
        repository: repositoryB,
        state: stateB,
        local: localB,
        vaultKeyBytes: await vaultKeyB.extractBytes(),
      ),
      clientA: clientA,
      clientB: clientB,
    );
  }

  /// Closes both devices' relay connections.
  Future<void> dispose() async {
    await _clientA.dispose();
    await _clientB.dispose();
  }

  static Future<NostrClient> _connectClient(LocalNostrSigner signer) async {
    final client = NostrClient(
      config: NostrClientConfig(signer: signer),
      relayManagerConfig: RelayManagerConfig(
        defaultRelayUrl: _relayUrl,
        storage: InMemoryRelayStorage(),
      ),
    );
    await client.initialize();
    return client;
  }

  static Future<void> _waitForVaultKeyEvent(
    NostrClient client,
    String pubkeyHex, {
    int maxAttempts = 20,
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final result = await client.queryEventsDetailed(
        [
          Filter(
            kinds: [EventKind.appSpecificData],
            authors: [pubkeyHex],
            d: [vaultKeyDTag],
          ),
        ],
        useCache: false,
      );
      if (result.events.isNotEmpty) return;
      await Future<void>.delayed(retryDelay);
    }
    throw StateError(
      'vault key event for $pubkeyHex never appeared on the relay after '
      '$maxAttempts polling attempts',
    );
  }
}

class _InMemoryLocalSoundStore implements LocalSoundStore {
  final Map<String, Map<String, dynamic>> _sounds = {};

  @override
  Future<Map<String, Map<String, dynamic>>> readAll() async =>
      Map<String, Map<String, dynamic>>.from(_sounds);

  @override
  Future<void> upsert(String id, Map<String, dynamic> body) async {
    _sounds[id] = body;
  }

  @override
  Future<void> remove(String id) async => _sounds.remove(id);
}

class _InMemoryVaultKeyCache implements VaultKeyCache {
  final Map<String, String> _byPubkey = {};

  @override
  Future<String?> read(String pubkeyHex) async => _byPubkey[pubkeyHex];

  @override
  Future<void> write(String pubkeyHex, String base64Key) async {
    _byPubkey[pubkeyHex] = base64Key;
  }
}
