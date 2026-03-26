import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(ImageMetadataStripper, () {
    const channel = MethodChannel('image_metadata_stripper');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('stripMetadata', () {
      test('invokes stripImageMetadata with correct arguments', () async {
        await ImageMetadataStripper.stripMetadata(
          inputPath: '/tmp/input.jpg',
          outputPath: '/tmp/output.jpg',
        );

        expect(calls, hasLength(1));
        expect(calls.first.method, equals('stripImageMetadata'));
        expect(
          calls.first.arguments,
          equals({
            'inputPath': '/tmp/input.jpg',
            'outputPath': '/tmp/output.jpg',
          }),
        );
      });

      test('throws PlatformException on native error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(
                code: 'FILE_NOT_FOUND',
                message: 'Input file does not exist',
              );
            });

        expect(
          () => ImageMetadataStripper.stripMetadata(
            inputPath: '/nonexistent.jpg',
            outputPath: '/tmp/output.jpg',
          ),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('stripMetadataInPlace', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'image_metadata_stripper_unit_test_',
        );
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('calls stripMetadata and renames temp file back', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

        // Mock creates the .stripped output file
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              final args = call.arguments as Map;
              final outputPath = args['outputPath'] as String;
              await File(outputPath).writeAsBytes([0xFF, 0xD8, 0xFF, 0xDB]);
              return null;
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Verify channel was called with correct paths
        expect(calls, hasLength(1));
        expect(
          calls.first.arguments,
          equals({
            'inputPath': imageFile.path,
            'outputPath': '${imageFile.path}.stripped',
          }),
        );

        // Verify the original file was replaced
        expect(result.path, equals(imageFile.path));
        expect(result.existsSync(), isTrue);
        expect(
          await result.readAsBytes(),
          equals([0xFF, 0xD8, 0xFF, 0xDB]),
        );

        // Verify temp file no longer exists
        expect(
          File('${imageFile.path}.stripped').existsSync(),
          isFalse,
        );
      });

      test('returns original file when stripMetadata throws', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        final originalBytes = [0xFF, 0xD8, 0xFF, 0xE0];
        await imageFile.writeAsBytes(originalBytes);

        // Mock throws an exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              throw PlatformException(
                code: 'DECODE_ERROR',
                message: 'Failed to decode image',
              );
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Verify original file is returned unchanged
        expect(result.path, equals(imageFile.path));
        expect(await result.readAsBytes(), equals(originalBytes));
      });

      test('cleans up partial temp file on failure', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        final tempPath = '${imageFile.path}.stripped';

        // Simulate partial write by creating temp file, then mock throws
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              // Write partial temp file before throwing
              await File(tempPath).writeAsBytes([0xFF, 0xD8]);
              throw PlatformException(
                code: 'WRITE_ERROR',
                message: 'Failed to write output',
              );
            });

        await ImageMetadataStripper.stripMetadataInPlace(imageFile);

        // Verify temp file was cleaned up
        expect(File(tempPath).existsSync(), isFalse);
      });

      test('silently handles temp file deletion failure', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        final tempPath = '${imageFile.path}.stripped';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              // Create temp file, then make parent readonly so delete fails
              await File(tempPath).writeAsBytes([0xFF, 0xD8]);
              await Process.run('chmod', ['a-w', tempDir.path]);
              throw PlatformException(
                code: 'DECODE_ERROR',
                message: 'Failed to decode',
              );
            });

        // Should complete without throwing despite deletion failure
        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Restore permissions for tearDown cleanup
        await Process.run('chmod', ['a+w', tempDir.path]);

        expect(result.path, equals(imageFile.path));
        // Temp file still exists because deletion failed
        expect(File(tempPath).existsSync(), isTrue);
      });
    });
  });
}
