import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/services/web_video_access_service.dart';

void main() {
  group('WebVideoAccessService', () {
    test('maps 401 failures to ageRestricted status', () async {
      final service = WebVideoAccessService(
        headRequest: (uri) async => http.Response('', 401),
      );

      final status = await service.confirmFailureStatus(
        'https://media.divine.video/protected-video',
      );

      expect(status, PlaybackStatus.ageRestricted);
    });

    test('creates an object URL from authenticated bytes', () async {
      final created = <({List<int> bytes, String? mimeType})>[];
      final service = WebVideoAccessService(
        getRequest: (uri, {headers}) async {
          expect(headers, {'Authorization': 'Nostr viewer-token'});
          return http.Response.bytes(
            [1, 2, 3, 4],
            200,
            headers: {'content-type': 'video/mp4'},
          );
        },
        createObjectUrl: (bytes, {mimeType}) {
          created.add((bytes: bytes, mimeType: mimeType));
          return 'blob:verified-video';
        },
      );

      final resolved = await service.resolveAuthenticatedPlayback(
        url: 'https://media.divine.video/protected-video',
        headers: const {'Authorization': 'Nostr viewer-token'},
        fallbackMimeType: 'video/mp4',
      );

      expect(resolved, isNotNull);
      expect(resolved!.url, 'blob:verified-video');
      expect(resolved.isObjectUrl, isTrue);
      expect(created, hasLength(1));
      expect(created.single.bytes, [1, 2, 3, 4]);
      expect(created.single.mimeType, 'video/mp4');
    });
  });
}
