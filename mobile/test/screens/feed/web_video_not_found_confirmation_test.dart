import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

void main() {
  test('confirms web video is session-missing only on HEAD 404', () async {
    final client = MockClient((request) async {
      expect(request.method, 'HEAD');
      return http.Response('', 404);
    });

    expect(
      await confirmWebVideoNotFound(
        'https://example.com/missing.mp4',
        client: client,
      ),
      isTrue,
    );
  });

  test('does not mark web video missing on non-404 responses', () async {
    final client = MockClient((request) async => http.Response('', 200));

    expect(
      await confirmWebVideoNotFound(
        'https://example.com/ok.mp4',
        client: client,
      ),
      isFalse,
    );
  });
}
