// ABOUTME: Tests for CollaboratorConfirmationRepository.

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

class _StaticLocalStateReader implements CollaboratorInviteLocalStateReader {
  _StaticLocalStateReader(this._states);

  final Map<String, CollaboratorStatus> _states;

  @override
  CollaboratorStatus? readLocalState({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
  }) {
    return _states['$videoAddress|$creatorPubkey|$collaboratorPubkey'];
  }
}

const _videoAddress = '34236:abc:vine-1';
const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaboratorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _secondCollaboratorPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _strangerPubkey =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Event _acceptanceEvent({
  required String pubkey,
  String videoAddress = _videoAddress,
  String statusValue = 'accepted',
  String addressTag = 'a',
}) {
  return Event(pubkey, 34238, [
    [addressTag, videoAddress, 'wss://relay.divine.video', 'root'],
    ['p', _creatorPubkey],
    ['role', 'Collaborator'],
    ['status', statusValue],
  ], '');
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeFilter());
  });

  group(CollaboratorConfirmationRepository, () {
    late _MockNostrClient nostrClient;
    late StreamController<Event> relayController;

    setUp(() {
      nostrClient = _MockNostrClient();
      relayController = StreamController<Event>.broadcast();
      when(
        () => nostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => relayController.stream);
    });

    tearDown(() async {
      await relayController.close();
    });

    test(
      'inviter view: pending entries flip to confirmed on kind-34238 echo',
      () async {
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _creatorPubkey,
        );

        final emissions = <VideoCollaboratorStatus>[];
        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [
                _collaboratorPubkey,
                _secondCollaboratorPubkey,
              ],
            )
            .listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        expect(emissions, isNotEmpty);
        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.pending),
        );
        expect(
          emissions.last.statusFor(_secondCollaboratorPubkey),
          equals(CollaboratorStatus.pending),
        );

        relayController.add(_acceptanceEvent(pubkey: _collaboratorPubkey));
        await Future<void>.delayed(Duration.zero);

        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.confirmed),
        );
        // Other collaborator stays pending.
        expect(
          emissions.last.statusFor(_secondCollaboratorPubkey),
          equals(CollaboratorStatus.pending),
        );

        await sub.cancel();
        repo.release(_videoAddress);
      },
    );

    test('rejects kind-34238 acceptance from a non-tagged pubkey', () async {
      final repo = CollaboratorConfirmationRepository(
        nostrClient: nostrClient,
        localStateReader: _StaticLocalStateReader(const {}),
        currentUserPubkey: _creatorPubkey,
      );

      final emissions = <VideoCollaboratorStatus>[];
      final sub = repo
          .watch(
            _videoAddress,
            creatorPubkey: _creatorPubkey,
            taggedPubkeys: const [_collaboratorPubkey],
          )
          .listen(emissions.add);

      await Future<void>.delayed(Duration.zero);
      final beforeCount = emissions.length;

      relayController.add(_acceptanceEvent(pubkey: _strangerPubkey));
      await Future<void>.delayed(Duration.zero);

      // No new emission; stranger ignored.
      expect(emissions.length, equals(beforeCount));
      expect(
        emissions.last.statusFor(_collaboratorPubkey),
        equals(CollaboratorStatus.pending),
      );

      await sub.cancel();
      repo.release(_videoAddress);
    });

    test(
      'creator removal wins: re-watch with empty taggedPubkeys excludes '
      'previously-confirmed collaborators',
      () async {
        // Spec invariant from
        // docs/superpowers/plans/2026-04-25-collab-full-lifecycle.md:
        // "Creator removal always wins. If the latest creator-authored video
        // event no longer has the collaborator role `p` tag, Funnelcake must
        // remove the pending/confirmed edge even if an old acceptance event
        // still exists."
        //
        // Mobile-side analogue: even though `_relayAccepted` retains the
        // historical acceptance, a re-watch driven by the latest creator-
        // authored event with an empty (or shrunk) `taggedPubkeys` must
        // produce a snapshot that does not surface the removed collaborator.
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _creatorPubkey,
        );

        // Initial state: B is tagged and has accepted.
        final emissions = <VideoCollaboratorStatus>[];
        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        relayController.add(_acceptanceEvent(pubkey: _collaboratorPubkey));
        await Future<void>.delayed(Duration.zero);
        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.confirmed),
        );

        await sub.cancel();
        repo.release(_videoAddress);

        // Simulate the creator editing the video and removing B. A fresh
        // watcher arrives with the new (empty) tagged list.
        final reEmissions = <VideoCollaboratorStatus>[];
        final reSub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const <String>[],
            )
            .listen(reEmissions.add);

        await Future<void>.delayed(Duration.zero);

        // B was previously confirmed. The new snapshot must not surface them.
        expect(reEmissions.last.statusByPubkey, isEmpty);
        expect(
          reEmissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.pending),
          reason:
              'statusFor falls back to pending for unknown pubkeys; the key '
              'guarantee is that B is no longer in statusByPubkey.',
        );

        await reSub.cancel();
        repo.release(_videoAddress);
      },
    );

    test(
      'rejects events whose only address tag is `d` (NIP-33 self-id)',
      () async {
        // Defense in depth: even if a relay misbehaves and delivers an event
        // whose only address-shaped tag is `d` (the event's own addressable
        // id), we must NOT treat it as an acceptance for the video. Per
        // NIP-33, `a` is the reference to another addressable event; `d` is
        // self-identifying. The relay filter `#a` already excludes such
        // events, but the in-process check is what protects us if the relay
        // is wrong.
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _creatorPubkey,
        );

        final emissions = <VideoCollaboratorStatus>[];
        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        final beforeCount = emissions.length;

        relayController.add(
          _acceptanceEvent(
            pubkey: _collaboratorPubkey,
            addressTag: 'd',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(emissions.length, equals(beforeCount));
        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.pending),
        );

        await sub.cancel();
        repo.release(_videoAddress);
      },
    );

    test('ignores events without status=accepted', () async {
      final repo = CollaboratorConfirmationRepository(
        nostrClient: nostrClient,
        localStateReader: _StaticLocalStateReader(const {}),
        currentUserPubkey: _creatorPubkey,
      );

      final emissions = <VideoCollaboratorStatus>[];
      final sub = repo
          .watch(
            _videoAddress,
            creatorPubkey: _creatorPubkey,
            taggedPubkeys: const [_collaboratorPubkey],
          )
          .listen(emissions.add);

      await Future<void>.delayed(Duration.zero);
      final beforeCount = emissions.length;

      relayController.add(
        _acceptanceEvent(
          pubkey: _collaboratorPubkey,
          statusValue: 'declined',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, equals(beforeCount));
      expect(
        emissions.last.statusFor(_collaboratorPubkey),
        equals(CollaboratorStatus.pending),
      );

      await sub.cancel();
      repo.release(_videoAddress);
    });

    test(
      'recipient view: current user local store override flips current user '
      'status without a relay subscription',
      () async {
        // No NostrClient.subscribe call expected because current user is
        // NOT the creator.
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {
            '$_videoAddress|$_creatorPubkey|$_collaboratorPubkey':
                CollaboratorStatus.ignored,
          }),
          currentUserPubkey: _collaboratorPubkey,
        );

        final emissions = <VideoCollaboratorStatus>[];
        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen(emissions.add);

        await Future<void>.delayed(Duration.zero);

        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.ignored),
        );
        verifyNever(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        );

        await sub.cancel();
        repo.release(_videoAddress);
      },
    );

    test(
      'markLocal emits a new snapshot for the current user immediately',
      () async {
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _collaboratorPubkey,
        );

        final emissions = <VideoCollaboratorStatus>[];
        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.pending),
        );

        repo.markLocal(
          videoAddress: _videoAddress,
          collaboratorPubkey: _collaboratorPubkey,
          status: CollaboratorStatus.confirmed,
        );

        await Future<void>.delayed(Duration.zero);

        expect(
          emissions.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.confirmed),
        );

        await sub.cancel();
        repo.release(_videoAddress);
      },
    );

    test(
      'markLocal rejects writes for pubkeys other than the current user',
      () async {
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _collaboratorPubkey,
        );

        final emissions = <VideoCollaboratorStatus>[];
        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [
                _collaboratorPubkey,
                _secondCollaboratorPubkey,
              ],
            )
            .listen(emissions.add);

        await Future<void>.delayed(Duration.zero);

        repo.markLocal(
          videoAddress: _videoAddress,
          collaboratorPubkey: _secondCollaboratorPubkey,
          status: CollaboratorStatus.confirmed,
        );

        await Future<void>.delayed(Duration.zero);

        // Second collaborator status remains pending because the write was
        // rejected (not the current user).
        expect(
          emissions.last.statusFor(_secondCollaboratorPubkey),
          equals(CollaboratorStatus.pending),
        );

        await sub.cancel();
        repo.release(_videoAddress);
      },
    );

    test(
      'release decrements ref count; only closes when count drops to zero',
      () async {
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _creatorPubkey,
        );

        final emissions1 = <VideoCollaboratorStatus>[];
        final emissions2 = <VideoCollaboratorStatus>[];
        final sub1 = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen(emissions1.add);
        final sub2 = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen(emissions2.add);

        await Future<void>.delayed(Duration.zero);

        // Release once — still one watcher; relay event should still emit.
        repo.release(_videoAddress);

        relayController.add(_acceptanceEvent(pubkey: _collaboratorPubkey));
        await Future<void>.delayed(Duration.zero);

        expect(
          emissions1.last.statusFor(_collaboratorPubkey),
          equals(CollaboratorStatus.confirmed),
        );

        // Final release — closes.
        repo.release(_videoAddress);
        expect(repo.current(_videoAddress).statusByPubkey, isEmpty);

        await sub1.cancel();
        await sub2.cancel();
      },
    );

    test(
      'does not open a relay subscription when current user is not the '
      'creator',
      () async {
        final repo = CollaboratorConfirmationRepository(
          nostrClient: nostrClient,
          localStateReader: _StaticLocalStateReader(const {}),
          currentUserPubkey: _strangerPubkey,
        );

        final sub = repo
            .watch(
              _videoAddress,
              creatorPubkey: _creatorPubkey,
              taggedPubkeys: const [_collaboratorPubkey],
            )
            .listen((_) {});

        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        );

        await sub.cancel();
        repo.release(_videoAddress);
      },
    );

    test('close cancels relay subs and clears state', () async {
      final repo = CollaboratorConfirmationRepository(
        nostrClient: nostrClient,
        localStateReader: _StaticLocalStateReader(const {}),
        currentUserPubkey: _creatorPubkey,
      );

      final sub = repo
          .watch(
            _videoAddress,
            creatorPubkey: _creatorPubkey,
            taggedPubkeys: const [_collaboratorPubkey],
          )
          .listen((_) {});

      await Future<void>.delayed(Duration.zero);

      await repo.close();
      expect(repo.current(_videoAddress).statusByPubkey, isEmpty);

      await sub.cancel();
    });
  });
}
