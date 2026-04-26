// ABOUTME: Tests local collaborator invite response state persistence.
// ABOUTME: Verifies state keys are scoped to video, creator, and collaborator.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const creatorPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const otherCollaboratorPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const videoAddress = '34236:$creatorPubkey:video-d-tag';

  late SharedPreferences prefs;
  late CollaboratorInviteStateStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    store = CollaboratorInviteStateStore(prefs: prefs);
  });

  group(CollaboratorInviteStateStore, () {
    test('defaults unknown invites to pending', () {
      expect(
        store.getState(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: collaboratorPubkey,
        ),
        CollaboratorInviteState.pending,
      );
    });

    test('persists accepting accepted ignored and failed states', () async {
      for (final state in CollaboratorInviteState.values) {
        await store.setState(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: collaboratorPubkey,
          state: state,
        );

        expect(
          store.getState(
            videoAddress: videoAddress,
            creatorPubkey: creatorPubkey,
            collaboratorPubkey: collaboratorPubkey,
          ),
          state,
        );
      }
    });

    test('persists state across store instances', () async {
      await store.setState(
        videoAddress: videoAddress,
        creatorPubkey: creatorPubkey,
        collaboratorPubkey: collaboratorPubkey,
        state: CollaboratorInviteState.accepted,
      );

      final reloaded = CollaboratorInviteStateStore(prefs: prefs);

      expect(
        reloaded.getState(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: collaboratorPubkey,
        ),
        CollaboratorInviteState.accepted,
      );
    });

    test('scopes state by collaborator pubkey', () async {
      await store.setState(
        videoAddress: videoAddress,
        creatorPubkey: creatorPubkey,
        collaboratorPubkey: collaboratorPubkey,
        state: CollaboratorInviteState.ignored,
      );

      expect(
        store.getState(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: otherCollaboratorPubkey,
        ),
        CollaboratorInviteState.pending,
      );
    });
  });
}
