import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(VideoBufferProfile, () {
    group('wireValue', () {
      // These literals are the cross-language contract with the native side:
      // Kotlin's BufferProfile.fromWireValue hardcodes "feed", so a rename of
      // the Dart enum value would silently fall back to FULL buffering on
      // Android and re-introduce the feed OOM (#3419). Pin the strings here so
      // such a rename breaks this test instead of slipping through.
      test('maps feed to the stable "feed" wire string', () {
        expect(VideoBufferProfile.feed.wireValue, equals('feed'));
      });

      test('maps full to the stable "full" wire string', () {
        expect(VideoBufferProfile.full.wireValue, equals('full'));
      });
    });
  });
}
