// ABOUTME: Integration test verifying video rendering strips GPS metadata
// ABOUTME: Uses ProVideoEditor.getMetadata to check GPS before/after render

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:patrol/patrol.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// A minimal 320x240 1-second H.264 MP4 (isom brand) with GPS metadata
/// stored in BOTH `loci` (3GPP, for Android MediaMetadataRetriever) and
/// `©xyz` (QuickTime, for AVFoundation on iOS/macOS) atoms.
/// ~2 KB inline. moov at end so GPS atom insertion keeps stco valid.
const _gpsVideoBase64 =
    'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAABIFtZGF0AAACcQYF//9t'
    '3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBF'
    'Ry00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4u'
    'b3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTAgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFs'
    'eXNlPTB4MToweDExMSBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVk'
    'X3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MCBjcW09MCBk'
    'ZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTcg'
    'bG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRl'
    'cmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0wIHdl'
    'aWdodHA9MCBrZXlpbnQ9MjUwIGtleWludF9taW49MjUgc2NlbmVjdXQ9NDAgaW50cmFfcmVmcmVz'
    'aD0wIHJjX2xvb2thaGVhZD00MCByYz1jcmYgbWJ0cmVlPTEgY3JmPTIzLjAgcWNvbXA9MC42MCBx'
    'cG1pbj0wIHFwbWF4PTY5IHFwc3RlcD00IGlwX3JhdGlvPTEuNDAgYXE9MToxLjAwAIAAAAD4ZYiE'
    'DPEYoAApaxwABPajgACEDJycnJycnJycnJycnJycnJycnJ111111111111111111111111111111'
    '1111111111111111111111111111111111111111111111111111111111111111111111111111'
    '1111111111111111111111111111111111111111111111111111111111111111111111111111'
    '1111111111111111111111111111111111111111111111111111111111111111111111111111'
    '11111111111111111111114AAAAHQZo4GeAS2AAAAAdBmlQGeAS2AAAAB0GaYDPAJbAAAAAHQZqA'
    'M8AlsAAAAAdBmqAzwCWwAAAAB0GawDPAJbAAAAAHQZrgM8AlsAAAAAdBmwAzwCWwAAAAB0GbIDPA'
    'JbAAAAAHQZtAM8AlsAAAAAdBm2AzwCWwAAAAB0GbgDPAJbAAAAAHQZugM8AlsAAAAAdBm8AzwCWw'
    'AAAAB0Gb4DPAJbAAAAAHQZoAM8AlsAAAAAdBmiAzwCWwAAAAB0GaQDPAJbAAAAAHQZpgM8AlsAAA'
    'AAdBmoAzwCWwAAAAB0GaoDPAJbAAAAAHQZrAL8AlsAAAAAdBmuAvwCWwAAAAB0GbACvAJbAAAAPK'
    'bW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAA+gAAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAA'
    'AAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAA'
    'ArN0cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAA+gAAAAAAAAAAAAAAAAAAAAAAAEA'
    'AAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAUAAAADwAAAAAAAkZWR0cwAAABxlbHN0'
    'AAAAAAAAAAEAAAPoAAAAAAABAAAAAAIrbWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAAAyAAAAMgBV'
    'xAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAAB1m1pbmYA'
    'AAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAA'
    'AZZzdGJsAAAAunN0c2QAAAAAAAAAAQAAAKphdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAUAA'
    '8ABIAAAASAAAAAAAAAABFUxhdmM2Mi4yOC4xMDAgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAAMGF2'
    'Y0MBQsAe/+EAGGdCwB7ZAUH7ARAAAAMAEAAAAwMg8WLkgAEABWjLg8sgAAAAEHBhc3AAAAABAAAA'
    'AQAAABRidHJ0AAAAAAAAI8gAAAAAAAAAGHN0dHMAAAAAAAAAAQAAABkAAAIAAAAAFHN0c3MAAAAA'
    'AAAAAQAAAAEAAAAcc3RzYwAAAAAAAAABAAAAAQAAABkAAAABAAAAeHN0c3oAAAAAAAAAAAAAABkA'
    'AANxAAAACwAAAAsAAAALAAAACwAAAAsAAAALAAAACwAAAAsAAAALAAAACwAAAAsAAAALAAAACwAA'
    'AAsAAAALAAAACwAAAAsAAAALAAAACwAAAAsAAAALAAAACwAAAAsAAAALAAAAFHN0Y28AAAAAAAAA'
    'AQAAADAAAACjdWR0YQAAAFptZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAA'
    'AAAAAC1pbHN0AAAAJal0b28AAAAdZGF0YQAAAAEAAAAATGF2ZjYyLjEyLjEwMAAAACNsb2NpAAAA'
    'AAAAAAAACIqsAC9gfAAAAABlYXJ0aAAAAAAAHql4eXoAEgAAKzQ3LjM3NjkrMDA4LjU0MTcv';

void main() {
  group('VideoMetadataStripper Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'video_metadata_test_',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Writes the embedded GPS-tagged video fixture to a temp file.
    Future<String> writeFixture(String name) async {
      final bytes = base64Decode(_gpsVideoBase64);
      final path = '${tempDir.path}/$name';
      await File(path).writeAsBytes(bytes);
      return path;
    }

    patrolTest(
      'renderVideo strips GPS metadata from video',
      ($) async {
        final inputPath = await writeFixture('gps_video.mp4');

        // Verify GPS metadata is present in source video
        final sourceMeta = await ProVideoEditor.instance.getMetadata(
          EditorVideo.file(inputPath),
        );

        expect(
          sourceMeta.gpsCoordinates,
          isNotNull,
          reason: 'Source video must contain GPS coordinates',
        );
        expect(
          sourceMeta.gpsCoordinates!.latitude,
          closeTo(47.3769, 0.01),
        );
        expect(
          sourceMeta.gpsCoordinates!.longitude,
          closeTo(8.5417, 0.01),
        );

        // Render video through VideoEditorRenderService
        final clip = DivineVideoClip(
          id: 'test_gps_clip',
          video: EditorVideo.file(inputPath),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: model.AspectRatio.square,
          originalAspectRatio: 1,
        );

        final outputPath = await VideoEditorRenderService.renderVideo(
          clips: [clip],
          aspectRatio: model.AspectRatio.square,
        );

        expect(outputPath, isNotNull, reason: 'Render must succeed');

        // Verify GPS metadata is stripped after rendering
        final renderedMeta = await ProVideoEditor.instance.getMetadata(
          EditorVideo.file(outputPath),
        );

        expect(
          renderedMeta.gpsCoordinates,
          isNull,
          reason: 'Rendered video must not contain GPS coordinates',
        );

        // Clean up rendered file
        final renderedFile = File(outputPath!);
        if (renderedFile.existsSync()) await renderedFile.delete();
      },
    );

    patrolTest(
      'cropToAspectRatio strips GPS metadata',
      ($) async {
        final inputPath = await writeFixture('gps_crop_video.mp4');

        // Verify GPS is present
        final sourceMeta = await ProVideoEditor.instance.getMetadata(
          EditorVideo.file(inputPath),
        );
        expect(sourceMeta.gpsCoordinates, isNotNull);

        // Crop via the render service
        final croppedPath = await VideoEditorRenderService.cropToAspectRatio(
          video: EditorVideo.file(inputPath),
          aspectRatio: model.AspectRatio.vertical,
          metadata: sourceMeta,
        );

        // Verify GPS metadata is stripped after cropping
        final croppedMeta = await ProVideoEditor.instance.getMetadata(
          EditorVideo.file(croppedPath),
        );

        expect(
          croppedMeta.gpsCoordinates,
          isNull,
          reason: 'Cropped video must not contain GPS coordinates',
        );

        // Clean up
        if (croppedPath != inputPath) {
          final croppedFile = File(croppedPath);
          if (croppedFile.existsSync()) await croppedFile.delete();
        }
      },
    );
  });
}
