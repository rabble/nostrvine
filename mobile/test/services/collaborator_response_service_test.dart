// ABOUTME: Tests collaborator acceptance publishing.
// ABOUTME: Verifies accept mirrors Connect by publishing an accepter-owned video copy.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
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

  final sourceVideo = VideoEvent(
    id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    pubkey: creatorPubkey,
    createdAt: 1700000000,
    content: 'A collab video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    title: 'Collab Video',
    nostrEventTags: const [
      ['d', 'video-d-tag'],
      ['title', 'Collab Video'],
      ['p', collaboratorPubkey, 'wss://relay.divine.video', 'collaborator'],
      ['url', 'https://media.divine.video/video.mp4'],
    ],
  );

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
    when(() => authService.currentPublicKeyHex).thenReturn(collaboratorPubkey);
    service = CollaboratorResponseService(
      authService: authService,
      nostrClient: nostrClient,
      loadSourceVideo: (_) async => sourceVideo,
    );
  });

  test('publishes accepter-owned collaborator video copy', () async {
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
        34236,
        tags,
        'A collab video',
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

    expect(verification.captured[0], 34236);
    expect(verification.captured[1], 'A collab video');
    expect(verification.captured[2], [
      ['d', 'video-d-tag'],
      ['title', 'Collab Video'],
      ['url', 'https://media.divine.video/video.mp4'],
      ['p', creatorPubkey, '', 'collaborator'],
      [
        'e',
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        '',
        'source',
      ],
      ['a', videoAddress, 'wss://relay.divine.video', 'source'],
    ]);
    verify(() => nostrClient.publishEvent(signedEvent)).called(1);
  });

  test(
    'uses default relay hint for source address when invite has none',
    () async {
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
        return Event(collaboratorPubkey, 34236, capturedTags, 'A collab video');
      });
      when(() => nostrClient.publishEvent(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.single as Event,
      );

      final result = await service.acceptInvite(inviteWithoutRelay);

      expect(result.success, isTrue);
      expect(capturedTags.last, [
        'a',
        videoAddress,
        'wss://relay.divine.video',
        'source',
      ]);
    },
  );

  test('returns failure when source video cannot be loaded', () async {
    service = CollaboratorResponseService(
      authService: authService,
      nostrClient: nostrClient,
      loadSourceVideo: (_) async => null,
    );

    final result = await service.acceptInvite(invite);

    expect(result.success, isFalse);
    expect(result.error, contains('source video'));
    verifyNever(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    );
    verifyNever(() => nostrClient.publishEvent(any()));
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
