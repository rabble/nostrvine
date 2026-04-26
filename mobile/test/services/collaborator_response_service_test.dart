// ABOUTME: Tests public collaborator acceptance response publishing.
// ABOUTME: Verifies kind 34238 acceptance events match Funnelcake semantics.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/collaboration_event_kinds.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_response_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  const creatorPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const videoAddress = '34236:$creatorPubkey:video-d-tag';

  late _MockAuthService authService;
  late _MockNostrClient nostrClient;
  late CollaboratorResponseService service;

  const invite = CollaboratorInvite(
    messageId: 'message-id',
    videoAddress: videoAddress,
    videoKind: 34236,
    creatorPubkey: creatorPubkey,
    videoDTag: 'video-d-tag',
    role: 'Collaborator',
    relayHint: 'wss://relay.divine.video',
  );

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    authService = _MockAuthService();
    nostrClient = _MockNostrClient();
    service = CollaboratorResponseService(
      authService: authService,
      nostrClient: nostrClient,
    );
  });

  test('publishes public collaborator acceptance event', () async {
    late Event signedEvent;
    when(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      final tags = invocation.namedArguments[#tags] as List<List<String>>;
      signedEvent = Event(
        collaboratorPubkey,
        kindCollabResponse,
        tags,
        '',
      );
      return signedEvent;
    });
    when(() => nostrClient.publishEvent(any())).thenAnswer(
      (_) async => signedEvent,
    );

    final result = await service.acceptInvite(invite);

    expect(result.success, isTrue);
    expect(result.eventId, signedEvent.id);

    final verification = verify(
      () => authService.createAndSignEvent(
        kind: captureAny(named: 'kind'),
        content: captureAny(named: 'content'),
        tags: captureAny(named: 'tags'),
      ),
    );

    expect(verification.captured[0], kindCollabResponse);
    expect(verification.captured[1], '');
    expect(verification.captured[2], [
      ['d', videoAddress],
      ['a', videoAddress, 'wss://relay.divine.video', 'root'],
      ['p', creatorPubkey],
      ['role', 'Collaborator'],
      ['status', 'accepted'],
    ]);
    verify(() => nostrClient.publishEvent(signedEvent)).called(1);
  });

  test('uses default relay hint when invite has none', () async {
    late List<List<String>> capturedTags;
    final inviteWithoutRelay = CollaboratorInvite(
      messageId: invite.messageId,
      videoAddress: invite.videoAddress,
      videoKind: invite.videoKind,
      creatorPubkey: invite.creatorPubkey,
      videoDTag: invite.videoDTag,
      role: invite.role,
    );

    when(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
      return Event(collaboratorPubkey, kindCollabResponse, capturedTags, '');
    });
    when(() => nostrClient.publishEvent(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.single as Event,
    );

    final result = await service.acceptInvite(inviteWithoutRelay);

    expect(result.success, isTrue);
    expect(capturedTags[1], [
      'a',
      videoAddress,
      'wss://relay.divine.video',
      'root',
    ]);
  });

  test('returns failure when signing fails', () async {
    when(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async => null);

    final result = await service.acceptInvite(invite);

    expect(result.success, isFalse);
    expect(result.error, contains('sign'));
    verifyNever(() => nostrClient.publishEvent(any()));
  });
}
