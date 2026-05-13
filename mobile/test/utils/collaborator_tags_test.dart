// ABOUTME: Tests for the Divine collaborator p-tag helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/collaborator_tags.dart';

void main() {
  final pubkeyA = 'a' * 64;
  final pubkeyB = 'b' * 64;
  final pubkeyC = 'c' * 64;

  group('buildCollaboratorPTag', () {
    test(
      'builds a 4-element Divine-convention p-tag with lowercase marker',
      () {
        expect(
          buildCollaboratorPTag(pubkeyA),
          equals(['p', pubkeyA, collaboratorInviteRelayHint, 'collaborator']),
        );
      },
    );
  });

  group('buildCollaboratorPTags', () {
    test('returns an empty list for empty input', () {
      expect(buildCollaboratorPTags(const <String>[]), isEmpty);
    });

    test('plural output equals iteration of singular over the same input', () {
      final pubkeys = [pubkeyA, pubkeyB, pubkeyC];
      expect(
        buildCollaboratorPTags(pubkeys),
        equals(pubkeys.map(buildCollaboratorPTag).toList()),
      );
    });

    test('accepts a Set as well as a List', () {
      final pubkeys = <String>{pubkeyA, pubkeyB};
      final result = buildCollaboratorPTags(pubkeys);
      expect(result, hasLength(2));
      expect(
        result,
        everyElement(
          predicate<List<String>>(
            (tag) =>
                tag.length == 4 &&
                tag[0] == 'p' &&
                tag[2] == collaboratorInviteRelayHint &&
                tag[3] == 'collaborator',
          ),
        ),
      );
    });
  });
}
