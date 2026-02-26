// Script to generate blurhash from test video
// Run with: dart run test/fixtures/generate_test_blurhash.dart

import 'dart:io';

import 'package:openvine/services/blurhash_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

Future<void> main() async {
  const testVideoPath = 'test/fixtures/test_video.mp4';

  print('Extracting thumbnail from test video...');
  final thumbnailResult = await VideoThumbnailService.extractThumbnailBytes(
    videoPath: testVideoPath,
  );

  if (thumbnailResult == null) {
    print('❌ Failed to extract thumbnail');
    exit(1);
  }

  print('✅ Extracted thumbnail: ${thumbnailResult.bytes.length} bytes');

  print('Generating blurhash...');
  final blurhash = await BlurhashService.generateBlurhash(
    thumbnailResult.bytes,
  );

  if (blurhash == null) {
    print('❌ Failed to generate blurhash');
    exit(1);
  }

  print('✅ Generated blurhash: $blurhash');
  print('');
  print('Use this blurhash in your tests:');
  print("const testBlurhash = '$blurhash';");
}
