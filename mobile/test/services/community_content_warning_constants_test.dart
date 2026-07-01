import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/community_content_warning_constants.dart';

void main() {
  group(CommunityContentWarningConstants, () {
    test('display threshold is 3 distinct Divine-identity authors', () {
      expect(CommunityContentWarningConstants.displayThreshold, equals(3));
    });

    test('namespace matches the NIP-32 content-warning namespace', () {
      expect(
        CommunityContentWarningConstants.namespace,
        equals('content-warning'),
      );
    });
  });
}
