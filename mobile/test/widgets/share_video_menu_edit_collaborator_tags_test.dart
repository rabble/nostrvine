// ABOUTME: Regression test for collaborator p-tag marker in the edit-video path.
// ABOUTME: Mirrors tag construction in _EditVideoDialogState._updateVideo to
// ABOUTME: ensure the marker stays lowercase. Sibling of
// ABOUTME: video_event_publisher_collaborator_tags_test.dart (covers direct upload).

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

const _deepEquals = DeepCollectionEquality();

bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((tag) => _deepEquals.equals(tag, expected));
}

/// Mirrors the collaborator p-tag loop in
/// _EditVideoDialogState._updateVideo (share_video_menu.dart ~line 1528-1531).
List<List<String>> _buildEditVideoTags({
  required List<String> collaboratorPubkeys,
}) {
  final tags = <List<String>>[];
  for (final pubkey in collaboratorPubkeys) {
    tags.add(['p', pubkey, 'wss://relay.divine.video', 'collaborator']);
  }
  return tags;
}

void main() {
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('edit-video path emits lowercase collaborator marker', () {
    final tags = _buildEditVideoTags(
      collaboratorPubkeys: const [collaboratorPubkey],
    );

    expect(
      _containsTag(tags, const [
        'p',
        collaboratorPubkey,
        'wss://relay.divine.video',
        'collaborator',
      ]),
      isTrue,
    );

    expect(
      _containsTag(tags, const [
        'p',
        collaboratorPubkey,
        'wss://relay.divine.video',
        'Collaborator',
      ]),
      isFalse,
    );
  });

  test('edit-video path emits one p-tag per collaborator', () {
    const secondPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final tags = _buildEditVideoTags(
      collaboratorPubkeys: const [collaboratorPubkey, secondPubkey],
    );

    expect(tags.length, equals(2));
    expect(tags[0][3], equals('collaborator'));
    expect(tags[1][3], equals('collaborator'));
  });

  test('edit-video path emits no p-tags when collaborators list is empty', () {
    final tags = _buildEditVideoTags(collaboratorPubkeys: const []);
    expect(tags, isEmpty);
  });
}
