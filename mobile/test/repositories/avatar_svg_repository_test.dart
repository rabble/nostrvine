import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';

void main() {
  const url = 'https://divine.video/avatar.svg';
  final validSvgBytes = Uint8List.fromList(
    utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" />',
    ),
  );

  HttpAvatarSvgRepository repositoryFor(http.Response response) {
    return HttpAvatarSvgRepository(client: MockClient((_) async => response));
  }

  test('accepts well-formed SVG payloads', () async {
    final repository = repositoryFor(
      http.Response.bytes(
        validSvgBytes,
        200,
        headers: {'content-type': 'image/svg+xml; charset=utf-8'},
      ),
    );

    await expectLater(repository.load(url), completion(validSvgBytes));
  });

  test('accepts SVG payloads by sniffing when content type is missing', () {
    final repository = repositoryFor(http.Response.bytes(validSvgBytes, 200));

    expect(repository.load(url), completion(validSvgBytes));
  });

  test('rejects HTML returned from a .svg URL', () {
    final repository = repositoryFor(
      http.Response(
        '<html><body>not an svg</body></html>',
        200,
        headers: {'content-type': 'text/html'},
      ),
    );

    expect(repository.load(url), completion(isNull));
  });

  test('rejects malformed SVG before flutter_svg sees it', () {
    final repository = repositoryFor(
      http.Response(
        '<svg xmlns="http://www.w3.org/2000/svg"><path',
        200,
        headers: {'content-type': 'image/svg+xml'},
      ),
    );

    expect(repository.load(url), completion(isNull));
  });

  test('rejects non-200 responses', () {
    final repository = repositoryFor(
      http.Response(
        '<svg xmlns="http://www.w3.org/2000/svg" />',
        503,
        headers: {'content-type': 'image/svg+xml'},
      ),
    );

    expect(repository.load(url), completion(isNull));
  });

  test('rejects oversized responses', () {
    final oversized = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg"><text>${'x' * AvatarSvgRepositoryConfig.maxBytes}</text></svg>',
      ),
    );
    final repository = repositoryFor(
      http.Response.bytes(
        oversized,
        200,
        headers: {'content-type': 'image/svg+xml'},
      ),
    );

    expect(repository.load(url), completion(isNull));
  });

  test('caches negative results', () async {
    var requests = 0;
    final repository = HttpAvatarSvgRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('<html>gone</html>', 200);
      }),
    );

    await repository.load(url);
    await repository.load(url);

    expect(requests, 1);
  });
}
