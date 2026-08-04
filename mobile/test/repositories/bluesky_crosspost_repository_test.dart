import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/repositories/bluesky_crosspost_repository.dart';
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockCrosspostApiClient extends Mock implements CrosspostApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(BlueskyCrosspostRepository, () {
    late _MockCrosspostApiClient apiClient;
    late _MockProfileRepository profileRepository;
    late BlueskyCrosspostRepository repository;

    const pubkey = 'abc123def456';

    setUp(() {
      apiClient = _MockCrosspostApiClient();
      profileRepository = _MockProfileRepository();
      repository = BlueskyCrosspostRepository(
        apiClient: apiClient,
        profileRepository: profileRepository,
      );
      when(
        () => profileRepository.lookupUsernameByPubkey(
          pubkeyHex: any(named: 'pubkeyHex'),
        ),
      ).thenAnswer(
        (_) async =>
            const DivineUsernameFound(name: 'testuser', canonical: 'testuser'),
      );
    });

    group('loadStatus', () {
      test('uses keycast username when present', () async {
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(
            crosspostEnabled: true,
            username: 'keycastuser',
            handle: 'keycastuser.divine.video',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
          ),
        );

        final status = await repository.loadStatus(pubkey: pubkey);

        expect(status.crosspostEnabled, isTrue);
        expect(status.username, 'keycastuser');
        expect(status.handle, 'keycastuser.divine.video');
        expect(status.did, 'did:plc:test123');
        expect(status.usernameClaimStatus, UsernameClaimStatus.claimed);
      });

      test(
        'falls back to name server username when keycast omits it',
        () async {
          when(() => apiClient.getStatus()).thenAnswer(
            (_) async => const CrosspostStatus(
              crosspostEnabled: false,
              provisioningState: AtprotoProvisioningState.notLinked,
            ),
          );

          final status = await repository.loadStatus(pubkey: pubkey);

          expect(status.username, 'testuser');
          expect(status.handle, 'testuser.divine.video');
          expect(status.usernameClaimStatus, UsernameClaimStatus.claimed);
        },
      );

      test('keeps failed provisioning error as domain display data', () async {
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(
            crosspostEnabled: false,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.failed,
            provisioningError: 'PDS quota exhausted',
          ),
        );

        final status = await repository.loadStatus(pubkey: pubkey);

        expect(status.provisioningState, AtprotoProvisioningState.failed);
        expect(status.provisioningError, 'PDS quota exhausted');
      });
    });

    group('setCrosspost', () {
      test('sets crosspost and merges claim status', () async {
        when(
          () => apiClient.setCrosspost(pubkey: pubkey, enabled: true),
        ).thenAnswer(
          (_) async => const CrosspostStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
          ),
        );

        final status = await repository.setCrosspost(
          pubkey: pubkey,
          enabled: true,
        );

        expect(status.crosspostEnabled, isTrue);
        expect(status.provisioningState, AtprotoProvisioningState.pending);
        expect(status.usernameClaimStatus, UsernameClaimStatus.claimed);
      });
    });
  });
}
