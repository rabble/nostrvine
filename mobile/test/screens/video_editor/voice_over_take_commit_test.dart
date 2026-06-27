// ABOUTME: Unit tests for the voice-over take commit helpers.
// ABOUTME: Covers duration-probe branches and unplaced-take file cleanup.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/screens/video_editor/voice_over_take_commit.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends ProVideoEditor {
  _MockProVideoEditor({this.durationMs = 0, this.shouldThrow = false});

  final int durationMs;
  final bool shouldThrow;
  int metadataCalls = 0;

  @override
  void initializeStream() {}

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    metadataCalls++;
    if (shouldThrow) throw Exception('probe failed');
    return VideoMetadata.fromMap({'duration': durationMs}, 'mp4');
  }
}

AudioEvent _take({String filePath = '/tmp/take.m4a', double? duration}) =>
    AudioEvent.fromLocalImport(
      id: 'local_import_voice_over_a',
      filePath: filePath,
      createdAt: 0,
      title: 'Recording 1',
      mimeType: 'audio/mp4',
      duration: duration,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProVideoEditor original;

  setUp(() {
    original = ProVideoEditor.instance;
  });

  tearDown(() {
    ProVideoEditor.instance = original;
  });

  group('resolveRecordedTakeDurationSecs', () {
    test('returns the probed duration when the probe succeeds', () async {
      ProVideoEditor.instance = _MockProVideoEditor(durationMs: 2000);

      final secs = await resolveRecordedTakeDurationSecs(_take(duration: 1));

      expect(secs, equals(2.0));
    });

    test('falls back to the estimate when the probe returns zero', () async {
      ProVideoEditor.instance = _MockProVideoEditor();

      final secs = await resolveRecordedTakeDurationSecs(_take(duration: 1.5));

      expect(secs, equals(1.5));
    });

    test('falls back to the estimate when the probe throws', () async {
      ProVideoEditor.instance = _MockProVideoEditor(shouldThrow: true);

      final secs = await resolveRecordedTakeDurationSecs(_take(duration: 0.8));

      expect(secs, equals(0.8));
    });

    test(
      'returns the estimate without probing when the path is empty',
      () async {
        final mock = _MockProVideoEditor(durationMs: 2000);
        ProVideoEditor.instance = mock;

        final secs = await resolveRecordedTakeDurationSecs(
          _take(filePath: '', duration: 0.7),
        );

        expect(secs, equals(0.7));
        expect(mock.metadataCalls, equals(0));
      },
    );

    test('clamps a negative estimate to zero when the path is empty', () async {
      final secs = await resolveRecordedTakeDurationSecs(
        _take(filePath: '', duration: -5),
      );

      expect(secs, equals(0.0));
    });

    test(
      'clamps a negative estimate to zero when the probe returns zero',
      () async {
        ProVideoEditor.instance = _MockProVideoEditor();

        final secs = await resolveRecordedTakeDurationSecs(_take(duration: -2));

        expect(secs, equals(0.0));
      },
    );
  });

  group('deleteVoiceOverTakeFiles', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('voice_over_commit_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('deletes the local files backing the takes', () async {
      final fileA = File('${tempDir.path}/a.m4a')..writeAsStringSync('audio');
      final fileB = File('${tempDir.path}/b.m4a')..writeAsStringSync('audio');

      await deleteVoiceOverTakeFiles([
        _take(filePath: fileA.path),
        _take(filePath: fileB.path),
      ]);

      expect(fileA.existsSync(), isFalse);
      expect(fileB.existsSync(), isFalse);
    });

    test('ignores a null take list', () async {
      await expectLater(deleteVoiceOverTakeFiles(null), completes);
    });

    test('ignores takes whose file is already gone', () async {
      final missing = '${tempDir.path}/missing.m4a';

      await expectLater(
        deleteVoiceOverTakeFiles([_take(filePath: missing)]),
        completes,
      );
    });
  });
}
