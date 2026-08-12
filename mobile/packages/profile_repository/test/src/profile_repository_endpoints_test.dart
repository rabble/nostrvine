// ABOUTME: Pins the injectable name-server / Keycast endpoints on
// ABOUTME: ProfileRepository — production defaults, per-endpoint injection,
// ABOUTME: and the NIP-98 signed-URL-equals-requested-URL coupling.

import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockHttpClient extends Mock implements Client {}

/// Deliberately distinct per endpoint, and deliberately NOT the production
/// host, so a call site that reads a neighbouring endpoint fails loudly.
const _testNameServer = 'https://names.test.example';
const _testKeycastNip05 = 'https://login.test.example/.well-known/nostr.json';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback.test.example'));
  });

  group('ProfileRepository endpoints', () {
    late _MockNostrClient nostrClient;
    late _MockUserProfilesDao userProfilesDao;
    late _MockHttpClient httpClient;

    setUp(() {
      nostrClient = _MockNostrClient();
      userProfilesDao = _MockUserProfilesDao();
      httpClient = _MockHttpClient();
    });

    ProfileRepository buildRepository({
      String? nameServerBaseUrl,
      String? keycastNip05Url,
    }) {
      return ProfileRepository(
        nostrClient: nostrClient,
        userProfilesDao: userProfilesDao,
        httpClient: httpClient,
        nameServerBaseUrl: nameServerBaseUrl ?? defaultNameServerBaseUrl,
        keycastNip05Url: keycastNip05Url ?? defaultKeycastNip05Url,
      );
    }

    group('production defaults', () {
      // Bound to the shipped constants, not to literals restated here, so a
      // change to either default is what turns these red.
      test('name server origin is unchanged', () {
        expect(
          defaultNameServerBaseUrl,
          equals('https://names.divine.video'),
        );
      });

      test('keycast NIP-05 document is unchanged', () {
        expect(
          defaultKeycastNip05Url,
          equals('https://login.divine.video/.well-known/nostr.json'),
        );
      });

      // NIP-98 binds the absolute request URL by exact string equality and
      // the unsigned endpoints interpolate onto the base, so a shipped value
      // that is not already its own canonical form silently 401s or 404s.
      // Dot segments are the worst case: they route fine on the unsigned
      // GETs and reject on claim/release.
      for (final url in const [
        defaultNameServerBaseUrl,
        defaultKeycastNip05Url,
      ]) {
        test('$url is already canonical', () {
          expect(
            Uri.parse(url).toString(),
            equals(url),
            reason: 'not a fixed point of Uri normalization',
          );
          expect(url, isNot(endsWith('/')), reason: 'would double a slash');
          expect(url, isNot(contains('?')), reason: 'would corrupt ?name=');
          expect(Uri.parse(url).userInfo, isEmpty);
          expect(Uri.parse(url).hasPort, isFalse, reason: 'explicit port');
          expect(Uri.parse(url).pathSegments, isNot(contains('.')));
          expect(Uri.parse(url).pathSegments, isNot(contains('..')));
        });
      }
    });

    group('injection', () {
      test(
        'checkUsernameAvailability requests the injected name server',
        () async {
          when(() => httpClient.get(any())).thenAnswer(
            (_) async => Response(jsonEncode({'available': true}), 200),
          );

          await buildRepository(
            nameServerBaseUrl: _testNameServer,
          ).checkUsernameAvailability(username: 'alice');

          verify(
            () => httpClient.get(
              Uri.parse('$_testNameServer/api/username/check/alice'),
            ),
          ).called(1);
        },
      );

      test(
        'checkUsernameAvailability probes the injected keycast URL',
        () async {
          when(
            () => httpClient.get(
              Uri.parse('$_testNameServer/api/username/check/alice'),
            ),
          ).thenAnswer(
            (_) async => Response(jsonEncode({'available': true}), 200),
          );
          when(
            () => httpClient.get(Uri.parse('$_testKeycastNip05?name=alice')),
          ).thenAnswer(
            (_) async =>
                Response(jsonEncode({'names': <String, String>{}}), 200),
          );

          await buildRepository(
            nameServerBaseUrl: _testNameServer,
            keycastNip05Url: _testKeycastNip05,
          ).checkUsernameAvailability(username: 'alice');

          verify(
            () => httpClient.get(Uri.parse('$_testKeycastNip05?name=alice')),
          ).called(1);
        },
      );

      test('getUsernameByPubkey requests the injected name server', () async {
        const pubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        when(() => httpClient.get(any())).thenAnswer(
          (_) async => Response('{}', 404),
        );

        await buildRepository(
          nameServerBaseUrl: _testNameServer,
        ).getUsernameByPubkey(pubkeyHex: pubkey);

        verify(
          () => httpClient.get(
            Uri.parse('$_testNameServer/api/username/by-pubkey/$pubkey'),
          ),
        ).called(1);
      });

      test(
        'a trailing slash on the base does not double the separator',
        () async {
          when(() => httpClient.get(any())).thenAnswer(
            (_) async => Response(jsonEncode({'available': true}), 200),
          );

          await buildRepository(
            nameServerBaseUrl: '$_testNameServer/',
          ).checkUsernameAvailability(username: 'alice');

          verify(
            () => httpClient.get(
              Uri.parse('$_testNameServer/api/username/check/alice'),
            ),
          ).called(1);
        },
      );
    });

    group('NIP-98 signed URL equals requested URL', () {
      // The signed 'u' tag and the wire URL must be the same string: the name
      // server compares them byte-for-byte. Nothing else in the suite covers
      // this coupling, and a divergence 401s every claim and release.
      test('claimUsername signs exactly the URL it posts to', () async {
        when(
          () => nostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => 'Nostr fake');
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('{}', 500));

        await buildRepository(
          nameServerBaseUrl: _testNameServer,
        ).claimUsername(username: 'alice');

        final signed =
            verify(
                  () => nostrClient.createNip98AuthHeader(
                    url: captureAny(named: 'url'),
                    method: any(named: 'method'),
                    payload: any(named: 'payload'),
                  ),
                ).captured.single
                as String;
        final posted =
            verify(
                  () => httpClient.post(
                    captureAny(),
                    headers: any(named: 'headers'),
                    body: any(named: 'body'),
                  ),
                ).captured.single
                as Uri;

        expect(signed, equals(posted.toString()));
        expect(signed, equals('$_testNameServer/api/username/claim'));
      });

      test('releaseUsername signs exactly the URL it posts to', () async {
        when(
          () => nostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => 'Nostr fake');
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('{}', 500));

        await buildRepository(
          nameServerBaseUrl: _testNameServer,
        ).releaseUsername(name: 'alice');

        final signed =
            verify(
                  () => nostrClient.createNip98AuthHeader(
                    url: captureAny(named: 'url'),
                    method: any(named: 'method'),
                    payload: any(named: 'payload'),
                  ),
                ).captured.single
                as String;
        final posted =
            verify(
                  () => httpClient.post(
                    captureAny(),
                    headers: any(named: 'headers'),
                    body: any(named: 'body'),
                  ),
                ).captured.single
                as Uri;

        expect(signed, equals(posted.toString()));
        expect(signed, equals('$_testNameServer/api/username/release'));
      });
    });
  });
}
