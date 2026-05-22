import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/collaborator_invite_recovery_service.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaboratorA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collaboratorB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _videoAddress = '34236:$_ownerPubkey:video-1';

OutgoingDm _inviteRow({
  required String id,
  required String collaboratorPubkey,
  required OutgoingWrapStatus recipient,
  required OutgoingWrapStatus self,
  DateTime? queuedAt,
  String videoAddress = _videoAddress,
}) {
  final rumor = Event(_ownerPubkey, 14, [
    ['p', collaboratorPubkey],
    ['divine', 'collab-invite'],
    ['a', videoAddress, 'wss://relay.divine.video', 'root'],
    ['p', _ownerPubkey],
    ['role', 'Collaborator'],
    ['title', 'Beach post'],
    ['thumb', 'https://cdn.divine.video/thumb.jpg'],
  ], 'invite');
  return OutgoingDm(
    id: id,
    conversationId: 'conv:$id',
    recipientPubkey: collaboratorPubkey,
    content: 'invite',
    createdAt: rumor.createdAt,
    rumorEventJson: jsonEncode(rumor.toJson()),
    recipientWrapStatus: recipient,
    selfWrapStatus: self,
    queuedAt: queuedAt ?? DateTime.utc(2026, 5, 22, 13),
    ownerPubkey: _ownerPubkey,
  );
}

OutgoingDm _plainDmRow() {
  final rumor = Event(_ownerPubkey, 14, [
    ['p', _collaboratorA],
  ], 'hello');
  return OutgoingDm(
    id: 'plain',
    conversationId: 'conv:plain',
    recipientPubkey: _collaboratorA,
    content: 'hello',
    createdAt: rumor.createdAt,
    rumorEventJson: jsonEncode(rumor.toJson()),
    recipientWrapStatus: OutgoingWrapStatus.failed,
    selfWrapStatus: OutgoingWrapStatus.failed,
    queuedAt: DateTime.utc(2026, 5, 22, 13),
    ownerPubkey: _ownerPubkey,
  );
}

void main() {
  late _MockDmRepository dmRepository;
  late _MockOutgoingDmsDao outgoingDmsDao;
  late CollaboratorInviteRecoveryService service;

  setUp(() {
    dmRepository = _MockDmRepository();
    outgoingDmsDao = _MockOutgoingDmsDao();
    service = CollaboratorInviteRecoveryService(
      dmRepository: dmRepository,
      outgoingDmsDao: outgoingDmsDao,
      ownerPubkey: _ownerPubkey,
    );
  });

  test(
    'watchPendingInviteGroups emits only unresolved collaborator invites',
    () async {
      when(() => outgoingDmsDao.watchAllForOwner(_ownerPubkey)).thenAnswer(
        (_) => Stream.value([
          _inviteRow(
            id: 'failed-a',
            collaboratorPubkey: _collaboratorA,
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          ),
          _inviteRow(
            id: 'pending-b',
            collaboratorPubkey: _collaboratorB,
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
          ),
          _inviteRow(
            id: 'self-only',
            collaboratorPubkey: _collaboratorA,
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
          _plainDmRow(),
        ]),
      );

      final groups = await service.watchPendingInviteGroups().first;

      expect(groups, hasLength(1));
      expect(groups.single.videoAddress, _videoAddress);
      expect(groups.single.inviteCount, 2);
      expect(
        groups.single.collaboratorPubkeys,
        equals({_collaboratorA, _collaboratorB}),
      );
    },
  );

  test(
    'retryPendingInvitesForVideo recovers only matching unresolved rows',
    () async {
      when(() => outgoingDmsDao.watchAllForOwner(_ownerPubkey)).thenAnswer(
        (_) => Stream.value([
          _inviteRow(
            id: 'target-a',
            collaboratorPubkey: _collaboratorA,
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          ),
          _inviteRow(
            id: 'target-b',
            collaboratorPubkey: _collaboratorB,
            recipient: OutgoingWrapStatus.pending,
            self: OutgoingWrapStatus.pending,
          ),
          _inviteRow(
            id: 'other-video',
            collaboratorPubkey: _collaboratorA,
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
            videoAddress: '34236:$_ownerPubkey:video-2',
          ),
        ]),
      );
      when(
        () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
      ).thenAnswer((invocation) async {
        final rumorId = invocation.namedArguments[#rumorId] as String;
        return NIP17SendResult.success(
          rumorEventId: rumorId,
          messageEventId: 'wrap:$rumorId',
          recipientPubkey: _collaboratorA,
        );
      });

      final summary = await service.retryPendingInvitesForVideo(
        videoAddress: _videoAddress,
        collaboratorPubkeys: const [_collaboratorA],
      );

      expect(summary.attemptedCount, 1);
      expect(summary.successCount, 1);
      verify(() => dmRepository.recoverFullSend(rumorId: 'target-a')).called(1);
      verifyNever(() => dmRepository.recoverFullSend(rumorId: 'target-b'));
      verifyNever(() => dmRepository.recoverFullSend(rumorId: 'other-video'));
    },
  );

  test('retryPendingInvitesForVideo reports partial failures', () async {
    when(() => outgoingDmsDao.watchAllForOwner(_ownerPubkey)).thenAnswer(
      (_) => Stream.value([
        _inviteRow(
          id: 'target-a',
          collaboratorPubkey: _collaboratorA,
          recipient: OutgoingWrapStatus.failed,
          self: OutgoingWrapStatus.failed,
        ),
        _inviteRow(
          id: 'target-b',
          collaboratorPubkey: _collaboratorB,
          recipient: OutgoingWrapStatus.failed,
          self: OutgoingWrapStatus.failed,
        ),
      ]),
    );
    when(() => dmRepository.recoverFullSend(rumorId: 'target-a')).thenAnswer(
      (_) async => NIP17SendResult.success(
        rumorEventId: 'target-a',
        messageEventId: 'wrap:target-a',
        recipientPubkey: _collaboratorA,
      ),
    );
    when(
      () => dmRepository.recoverFullSend(rumorId: 'target-b'),
    ).thenAnswer((_) async => const NIP17SendResult.failure('relay timeout'));

    final summary = await service.retryPendingInvitesForVideo(
      videoAddress: _videoAddress,
    );

    expect(summary.attemptedCount, 2);
    expect(summary.successCount, 1);
    expect(summary.failureCount, 1);
  });
}
