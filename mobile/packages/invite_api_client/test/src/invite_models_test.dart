import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';

void main() {
  group('InviteStatus', () {
    test('claimedCodes returns only claimed codes', () {
      const status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 2,
        codes: [
          InviteCode(code: 'AAAA-BBBB', claimed: false),
          InviteCode(code: 'CCCC-DDDD', claimed: true, claimedBy: 'abc'),
        ],
      );

      expect(status.claimedCodes, hasLength(1));
      expect(status.claimedCodes.first.code, 'CCCC-DDDD');
    });

    test('unclaimedCodes returns only unclaimed codes', () {
      const status = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 2,
        codes: [
          InviteCode(code: 'AAAA-BBBB', claimed: false),
          InviteCode(code: 'CCCC-DDDD', claimed: true, claimedBy: 'abc'),
        ],
      );

      expect(status.unclaimedCodes, hasLength(1));
      expect(status.unclaimedCodes.first.code, 'AAAA-BBBB');
    });
  });
}
