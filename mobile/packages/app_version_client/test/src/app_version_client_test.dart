import 'dart:convert';

import 'package:app_version_client/app_version_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(AppVersionClient, () {
    late _MockHttpClient httpClient;
    late AppVersionClient client;

    setUp(() {
      httpClient = _MockHttpClient();
      client = AppVersionClient(httpClient: httpClient);
    });

    tearDown(() {
      client.dispose();
    });

    final expectedUri = Uri.parse(
      'https://api.github.com/repos/'
      '${AppVersionConstants.repoOwner}/'
      '${AppVersionConstants.repoName}/'
      'releases/latest',
    );

    group('fetchLatestRelease', () {
      test('returns AppVersionInfo on valid response', () async {
        when(
          () => httpClient.get(expectedUri, headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': '1.0.8',
              'published_at': '2026-04-02T02:04:42Z',
              'html_url':
                  'https://github.com/divinevideo/divine-mobile/releases/'
                  'tag/1.0.8',
              'body':
                  '# 1.0.8\n\n'
                  '- **Resumable uploads** -your loops survive bad signal\n'
                  '- **Double-tap to like** -you know the move\n'
                  '- **DMs leveled up** -clickable URLs and more\n',
            }),
            200,
          ),
        );

        final result = await client.fetchLatestRelease();

        expect(result.latestVersion, equals('1.0.8'));
        expect(
          result.publishedAt,
          equals(DateTime.parse('2026-04-02T02:04:42Z')),
        );
        expect(
          result.releaseNotesUrl,
          equals(
            'https://github.com/divinevideo/divine-mobile/releases/'
            'tag/1.0.8',
          ),
        );
        expect(
          result.releaseHighlights,
          equals([
            'Resumable uploads',
            'Double-tap to like',
            'DMs leveled up',
          ]),
        );
        expect(result.minimumVersion, isNull);
      });

      test('parses minimum_version from HTML comment in body', () async {
        when(
          () => httpClient.get(expectedUri, headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': '1.0.9',
              'published_at': '2026-04-10T00:00:00Z',
              'html_url':
                  'https://github.com/divinevideo/divine-mobile/releases/'
                  'tag/1.0.9',
              'body':
                  '<!-- minimum_version: 1.0.6 -->\n'
                  '# 1.0.9\n- **Security fix** -important patch\n',
            }),
            200,
          ),
        );

        final result = await client.fetchLatestRelease();

        expect(result.minimumVersion, equals('1.0.6'));
        expect(result.releaseHighlights, equals(['Security fix']));
      });

      test('returns empty highlights when body has no bold items', () async {
        when(
          () => httpClient.get(expectedUri, headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': '1.0.7',
              'published_at': '2026-03-01T00:00:00Z',
              'html_url':
                  'https://github.com/divinevideo/divine-mobile/releases/'
                  'tag/1.0.7',
              'body': 'Just a plain release with no highlights.',
            }),
            200,
          ),
        );

        final result = await client.fetchLatestRelease();

        expect(result.releaseHighlights, isEmpty);
      });

      test('throws AppVersionFetchException on non-200 status', () async {
        when(
          () => httpClient.get(expectedUri, headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        expect(
          () => client.fetchLatestRelease(),
          throwsA(isA<AppVersionFetchException>()),
        );
      });

      test('throws AppVersionFetchException on network error', () async {
        when(
          () => httpClient.get(expectedUri, headers: any(named: 'headers')),
        ).thenThrow(Exception('no internet'));

        expect(
          () => client.fetchLatestRelease(),
          throwsA(isA<AppVersionFetchException>()),
        );
      });

      test('throws AppVersionFetchException on malformed JSON', () async {
        when(
          () => httpClient.get(expectedUri, headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('not json', 200));

        expect(
          () => client.fetchLatestRelease(),
          throwsA(isA<AppVersionFetchException>()),
        );
      });
    });
  });
}
