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

    test('parses remainingToGenerate when the server reports it', () {
      final status = InviteStatus.fromJson(const {
        'canInvite': true,
        'remaining': 10,
        'remainingToGenerate': 3,
        'total': 10,
        'codes': <Map<String, dynamic>>[],
      });

      expect(status.remainingToGenerate, 3);
      expect(status.mintableCount, 3);
    });

    test('mintableCount falls back to remaining on an older server', () {
      final status = InviteStatus.fromJson(const {
        'canInvite': true,
        'remaining': 4,
        'total': 5,
        'codes': <Map<String, dynamic>>[],
      });

      expect(status.remainingToGenerate, isNull);
      expect(status.mintableCount, 4);
    });

    test('mintableCount empties while remaining holds', () {
      // The state that used to advertise a generate button the server rejects:
      // every code minted, none redeemed.
      final status = InviteStatus.fromJson(const {
        'canInvite': true,
        'remaining': 10,
        'remainingToGenerate': 0,
        'total': 10,
        'codes': <Map<String, dynamic>>[
          {'code': 'AAAA-BBBB', 'claimed': false},
        ],
      });

      expect(status.remaining, 10);
      expect(status.mintableCount, 0);
    });

    test('remainingToGenerate participates in equality', () {
      const a = InviteStatus(
        canInvite: true,
        remaining: 10,
        total: 10,
        codes: [],
        remainingToGenerate: 10,
      );
      const b = InviteStatus(
        canInvite: true,
        remaining: 10,
        total: 10,
        codes: [],
        remainingToGenerate: 0,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
