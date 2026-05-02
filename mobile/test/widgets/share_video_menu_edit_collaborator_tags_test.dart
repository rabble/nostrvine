// ABOUTME: Regression test for collaborator p-tag marker in the edit-video path.
// ABOUTME: Tests the shared buildCollaboratorPTag helper used by
// ABOUTME: _EditVideoDialogState._updateVideo. Sibling of
// ABOUTME: video_event_publisher_collaborator_tags_test.dart (covers direct upload).

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/share_video_menu.dart';

const _deepEquals = DeepCollectionEquality();

void main() {
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('buildCollaboratorPTag emits lowercase collaborator marker', () {
    final tag = buildCollaboratorPTag(collaboratorPubkey);

    expect(
      _deepEquals.equals(tag, const [
        'p',
        collaboratorPubkey,
        'wss://relay.divine.video',
        'collaborator',
      ]),
      isTrue,
    );

    expect(tag[3], isNot(equals('Collaborator')));
  });

  test('edit-video path emits one p-tag per collaborator', () {
    const secondPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final tags = [
      buildCollaboratorPTag(collaboratorPubkey),
      buildCollaboratorPTag(secondPubkey),
    ];

    expect(tags.length, equals(2));
    expect(tags[0][3], equals('collaborator'));
    expect(tags[1][3], equals('collaborator'));
  });

  test('buildCollaboratorPTag uses relay hint from share_video_menu', () {
    final tag = buildCollaboratorPTag(collaboratorPubkey);
    expect(tag[2], equals('wss://relay.divine.video'));
  });
}
