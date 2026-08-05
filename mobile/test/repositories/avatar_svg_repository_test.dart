import 'dart:async';
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
    return HttpAvatarSvgRepository(
      client: MockClient((_) async => response),
      requestTimeout: const Duration(milliseconds: 20),
    );
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

  test('rejects binary payloads without throwing while sniffing', () {
    final repository = repositoryFor(
      http.Response.bytes(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
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

  test('does not leave non-200 response stream errors unhandled', () async {
    final controller = StreamController<List<int>>();
    final repository = HttpAvatarSvgRepository(
      client: _StreamedAvatarClient(
        (_) async => http.StreamedResponse(
          controller.stream,
          503,
          headers: {'content-type': 'image/svg+xml'},
        ),
      ),
      requestTimeout: const Duration(milliseconds: 20),
    );

    final result = await repository.load(url);
    controller.addError(Exception('socket reset while discarding body'));

    expect(result, isNull);
    await controller.close();
  });

  test('times out incomplete response bodies', () async {
    var bodyCanceled = false;
    final controller = StreamController<List<int>>(
      onCancel: () {
        bodyCanceled = true;
      },
    );
    final repository = HttpAvatarSvgRepository(
      client: _StreamedAvatarClient(
        (_) async => http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'image/svg+xml'},
        ),
      ),
      requestTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(repository.load(url), completion(isNull));
    expect(bodyCanceled, isTrue);
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
      requestTimeout: const Duration(milliseconds: 20),
    );

    await repository.load(url);
    await repository.load(url);

    expect(requests, 1);
  });

  test('expires cached positive results after the positive TTL', () async {
    var now = DateTime(2026);
    var requests = 0;
    final repository = HttpAvatarSvgRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response.bytes(
          validSvgBytes,
          200,
          headers: {'content-type': 'image/svg+xml'},
        );
      }),
      clock: () => now,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await repository.load(url);
    now = now.add(const Duration(minutes: 30));
    await repository.load(url);
    now = now.add(const Duration(hours: 1, minutes: 1));
    await repository.load(url);

    expect(requests, 2);
  });

  test('expires cached negative results after the negative TTL', () async {
    var now = DateTime(2026);
    var requests = 0;
    final repository = HttpAvatarSvgRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('<html>gone</html>', 200);
      }),
      clock: () => now,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await repository.load(url);
    now = now.add(const Duration(minutes: 5));
    await repository.load(url);
    now = now.add(const Duration(minutes: 11));
    await repository.load(url);

    expect(requests, 2);
  });

  test('evicts least recently used cache entries', () async {
    var requests = 0;
    final repository = HttpAvatarSvgRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response.bytes(
          validSvgBytes,
          200,
          headers: {'content-type': 'image/svg+xml'},
        );
      }),
      requestTimeout: const Duration(milliseconds: 20),
    );

    for (
      var index = 0;
      index <= AvatarSvgRepositoryConfig.maxCacheEntries;
      index++
    ) {
      await repository.load('https://divine.video/avatar-$index.svg');
    }
    await repository.load('https://divine.video/avatar-0.svg');

    expect(requests, AvatarSvgRepositoryConfig.maxCacheEntries + 2);
  });

  test('deduplicates concurrent requests for the same URL', () async {
    var requests = 0;
    final responseCompleter = Completer<http.Response>();
    final repository = HttpAvatarSvgRepository(
      client: MockClient((_) {
        requests++;
        return responseCompleter.future;
      }),
      requestTimeout: const Duration(milliseconds: 20),
    );

    final first = repository.load(url);
    final second = repository.load(url);
    responseCompleter.complete(
      http.Response.bytes(
        validSvgBytes,
        200,
        headers: {'content-type': 'image/svg+xml'},
      ),
    );

    await expectLater(
      Future.wait([first, second]),
      completion([validSvgBytes, validSvgBytes]),
    );
    expect(requests, 1);
  });
}

class _StreamedAvatarClient extends http.BaseClient {
  _StreamedAvatarClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}
