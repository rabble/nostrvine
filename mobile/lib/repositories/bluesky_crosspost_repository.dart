// ABOUTME: Repository for Bluesky ATProto crosspost account settings
// ABOUTME: Composes keycast status with Divine username claim state

import 'package:equatable/equatable.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:profile_repository/profile_repository.dart';

/// Whether divine-name-server can confirm this pubkey owns an active
/// `.divine.video` username.
enum UsernameClaimStatus { unknown, claimed, notClaimed }

/// User-visible Bluesky crosspost settings state from keycast plus name server.
class BlueskyCrosspostAccountStatus extends Equatable {
  const BlueskyCrosspostAccountStatus({
    required this.crosspostEnabled,
    required this.provisioningState,
    required this.usernameClaimStatus,
    this.username,
    this.handle,
    this.did,
    this.provisioningError,
  });

  final bool crosspostEnabled;
  final AtprotoProvisioningState provisioningState;
  final UsernameClaimStatus usernameClaimStatus;
  final String? username;
  final String? handle;
  final String? did;
  final String? provisioningError;

  @override
  List<Object?> get props => [
    crosspostEnabled,
    provisioningState,
    usernameClaimStatus,
    username,
    handle,
    did,
    provisioningError,
  ];
}

/// Coordinates keycast ATProto status with Divine username ownership lookup.
class BlueskyCrosspostRepository {
  const BlueskyCrosspostRepository({
    required CrosspostApiClient apiClient,
    required ProfileRepository profileRepository,
  }) : _apiClient = apiClient,
       _profileRepository = profileRepository;

  final CrosspostApiClient _apiClient;
  final ProfileRepository _profileRepository;

  Future<BlueskyCrosspostAccountStatus> loadStatus({
    required String pubkey,
  }) async {
    final claimLookup = await _lookupUsernameClaimStatus(pubkey);
    final status = await _apiClient.getStatus();
    return _mergeStatus(status, claimLookup);
  }

  Future<BlueskyCrosspostAccountStatus> setCrosspost({
    required String pubkey,
    required bool enabled,
  }) async {
    final claimLookup = await _lookupUsernameClaimStatus(pubkey);
    final status = await _apiClient.setCrosspost(
      pubkey: pubkey,
      enabled: enabled,
    );
    return _mergeStatus(status, claimLookup);
  }

  BlueskyCrosspostAccountStatus _mergeStatus(
    CrosspostStatus status,
    ({UsernameClaimStatus status, String? username}) claimLookup,
  ) {
    final displayUsername = status.username ?? claimLookup.username;
    return BlueskyCrosspostAccountStatus(
      crosspostEnabled: status.crosspostEnabled,
      provisioningState: status.provisioningState,
      usernameClaimStatus: claimLookup.status,
      username: displayUsername,
      handle: _handleFor(displayUsername),
      did: status.did,
      provisioningError: status.provisioningError,
    );
  }

  Future<({UsernameClaimStatus status, String? username})>
  _lookupUsernameClaimStatus(String pubkey) async {
    final lookup = await _profileRepository.lookupUsernameByPubkey(
      pubkeyHex: pubkey,
    );
    return switch (lookup) {
      DivineUsernameFound(:final canonical) => (
        status: UsernameClaimStatus.claimed,
        username: canonical,
      ),
      DivineUsernameNotFound() => (
        status: UsernameClaimStatus.notClaimed,
        username: null,
      ),
      DivineUsernameUnknown() => (
        status: UsernameClaimStatus.unknown,
        username: null,
      ),
    };
  }

  String? _handleFor(String? username) {
    if (username == null || username.isEmpty) return null;
    return '$username.divine.video';
  }
}
