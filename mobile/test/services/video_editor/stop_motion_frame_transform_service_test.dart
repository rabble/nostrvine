// ABOUTME: Tests that a transformed stop-motion still lands in the documents
// ABOUTME: directory as a new file, never overwriting the still it came from.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/stop_motion_frame_transform_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform({required this.documentsPath});

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory tempDir;
  late String documentsPath;
  late PathProviderPlatform originalPathProvider;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stop_motion_frame_xf');
    documentsPath = p.join(tempDir.path, 'documents');
    Directory(documentsPath).createSync(recursive: true);

    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsPath,
    );
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProvider;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group(StopMotionFrameTransformService, () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    test('writes the bytes into the documents directory', () async {
      final path = await StopMotionFrameTransformService.writeTransformedFrame(
        bytes,
      );

      expect(p.dirname(path), documentsPath);
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('writes a jpg, matching the captured stills', () async {
      final path = await StopMotionFrameTransformService.writeTransformedFrame(
        bytes,
      );

      expect(p.extension(path), '.jpg');
    });

    test(
      'never reuses a path, so undo can still reach the previous still',
      () async {
        final first =
            await StopMotionFrameTransformService.writeTransformedFrame(bytes);
        final second =
            await StopMotionFrameTransformService.writeTransformedFrame(
              Uint8List.fromList([9, 9, 9]),
            );

        expect(second, isNot(first));
        expect(File(first).readAsBytesSync(), bytes);
      },
    );
  });
}
