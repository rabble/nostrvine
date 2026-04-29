// ABOUTME: Tests encrypted collaborator invite payload construction.
// ABOUTME: Verifies collab invites are NIP-17 DMs with structured tags.

import 'package:collection/collection.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/collaborator_invite_service.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _deepEquals = DeepCollectionEquality();

bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((tag) => _deepEquals.equals(tag, expected));
}

void main() {
  late _MockDmRepository dmRepository;
  late CollaboratorInviteService service;

  const creatorPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const videoAddress =
      '34236:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:video-id';

  setUp(() {
    dmRepository = _MockDmRepository();
    service = CollaboratorInviteService(dmRepository: dmRepository);
  });

  test('sends readable invite content with structured collab tags', () async {
    when(
      () => dmRepository.sendMessage(
        recipientPubkey: any(named: 'recipientPubkey'),
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        additionalTags: any(named: 'additionalTags'),
        skipNip04Fallback: any(named: 'skipNip04Fallback'),
      ),
    ).thenAnswer(
      (_) async => NIP17SendResult.success(
        rumorEventId: 'rumor-id',
        messageEventId: 'message-id',
        recipientPubkey: collaboratorPubkey,
      ),
    );

    final result = await service.sendInvite(
      collaboratorPubkey: collaboratorPubkey,
      creatorPubkey: creatorPubkey,
      videoAddress: videoAddress,
      title: 'Skate loop',
      thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
    );

    expect(result.success, isTrue);

    final verification = verify(
      () => dmRepository.sendMessage(
        recipientPubkey: collaboratorPubkey,
        content: captureAny(named: 'content'),
        replyToId: any(named: 'replyToId'),
        additionalTags: captureAny(named: 'additionalTags'),
        skipNip04Fallback: captureAny(named: 'skipNip04Fallback'),
      ),
    );

    final content = verification.captured[0] as String;
    final tags = verification.captured[1] as List<List<String>>;
    final skipNip04Fallback = verification.captured[2] as bool;

    expect(content, contains('Skate loop'));
    expect(content, contains('collaborate'));
    expect(_containsTag(tags, const ['divine', 'collab-invite']), isTrue);
    expect(
      _containsTag(tags, const [
        'a',
        videoAddress,
        'wss://relay.divine.video',
        'root',
      ]),
      isTrue,
    );
    expect(_containsTag(tags, const ['p', creatorPubkey]), isTrue);
    expect(_containsTag(tags, const ['role', 'Collaborator']), isTrue);
    expect(_containsTag(tags, const ['title', 'Skate loop']), isTrue);
    expect(
      _containsTag(tags, const [
        'thumb',
        'https://cdn.example.com/thumb.jpg',
      ]),
      isTrue,
    );
    // Structured invites must skip the NIP-04 legacy fallback — the
    // fallback would publish a duplicate plaintext message (#3559).
    expect(skipNip04Fallback, isTrue);
  });

  test(
    'content endsWith invitePlaintextSuffix (contract for UI suppression)',
    () async {
      when(
        () => dmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          additionalTags: any(named: 'additionalTags'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-id',
          messageEventId: 'message-id',
          recipientPubkey: collaboratorPubkey,
        ),
      );

      await service.sendInvite(
        collaboratorPubkey: collaboratorPubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
        title: 'Skate loop',
      );

      final captured =
          verify(
                () => dmRepository.sendMessage(
                  recipientPubkey: collaboratorPubkey,
                  content: captureAny(named: 'content'),
                  replyToId: any(named: 'replyToId'),
                  additionalTags: any(named: 'additionalTags'),
                  skipNip04Fallback: any(named: 'skipNip04Fallback'),
                ),
              ).captured.single
              as String;

      expect(
        captured.endsWith(CollaboratorInviteService.invitePlaintextSuffix),
        isTrue,
        reason:
            '_buildContent must end with invitePlaintextSuffix so the '
            'conversation view can suppress legacy NIP-04 duplicates (#3559)',
      );
    },
  );

  test('returns failure when encrypted DM send fails', () async {
    when(
      () => dmRepository.sendMessage(
        recipientPubkey: any(named: 'recipientPubkey'),
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        additionalTags: any(named: 'additionalTags'),
        skipNip04Fallback: any(named: 'skipNip04Fallback'),
      ),
    ).thenAnswer((_) async => NIP17SendResult.failure('relay unavailable'));

    final result = await service.sendInvite(
      collaboratorPubkey: collaboratorPubkey,
      creatorPubkey: creatorPubkey,
      videoAddress: videoAddress,
    );

    expect(result.success, isFalse);
    expect(result.error, 'relay unavailable');
  });
}
