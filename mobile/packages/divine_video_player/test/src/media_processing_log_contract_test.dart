import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native media-processing log contract', () {
    test('Android logs HTTP 202 media_processing as warning', () {
      final source = _androidSourceFile().readAsStringSync();

      final statusMapping = source.indexOf('status == 202');
      final mediaProcessingMapping = source.indexOf(
        '"media_processing"',
        statusMapping,
      );
      final errorCodeCapture = source.indexOf(
        'val nativeErrorCode = errorCodeFor(error)',
      );
      final mediaProcessingLogBranch = source.indexOf(
        'nativeErrorCode == "media_processing"',
        errorCodeCapture,
      );
      final warningLog = source.indexOf(
        'DivineVideoPlayerLog.warning',
        mediaProcessingLogBranch,
      );
      final errorLog = source.indexOf(
        'DivineVideoPlayerLog.error',
        mediaProcessingLogBranch,
      );

      expect(statusMapping, greaterThanOrEqualTo(0));
      expect(mediaProcessingMapping, greaterThan(statusMapping));
      expect(errorCodeCapture, greaterThan(mediaProcessingMapping));
      expect(mediaProcessingLogBranch, greaterThan(errorCodeCapture));
      expect(warningLog, greaterThan(mediaProcessingLogBranch));
      expect(
        warningLog,
        lessThan(errorLog),
        reason:
            'Handled HTTP 202 transcode-in-progress failures should stay out '
            'of ERROR telemetry while still preserving true playback errors.',
      );
    });

    test('Apple logs HTTP 202 media_processing as warning', () {
      final source = _appleSourceFile().readAsStringSync();

      final statusMapping = source.indexOf('httpResponse.statusCode == 202');
      final mediaProcessingMapping = source.indexOf(
        'return "media_processing"',
        statusMapping,
      );
      final compositionBranch = source.indexOf(
        'self.errorCode == "media_processing"',
      );
      final compositionWarning = source.indexOf(
        'DivineVideoPlayerLog.shared.warning',
        compositionBranch,
      );
      final compositionError = source.indexOf(
        'DivineVideoPlayerLog.shared.error',
        compositionBranch,
      );
      final itemBranch = source.indexOf(
        'self.errorCode == "media_processing"',
        compositionError,
      );
      final itemWarning = source.indexOf(
        'DivineVideoPlayerLog.shared.warning',
        itemBranch,
      );
      final itemError = source.indexOf(
        'DivineVideoPlayerLog.shared.error',
        itemBranch,
      );

      expect(statusMapping, greaterThanOrEqualTo(0));
      expect(mediaProcessingMapping, greaterThan(statusMapping));
      expect(compositionBranch, greaterThanOrEqualTo(0));
      expect(compositionWarning, greaterThan(compositionBranch));
      expect(compositionWarning, lessThan(compositionError));
      expect(itemBranch, greaterThan(compositionError));
      expect(itemWarning, greaterThan(itemBranch));
      expect(
        itemWarning,
        lessThan(itemError),
        reason:
            'Both Darwin composition-load and AVPlayerItem HTTP 202 failures '
            'should be warning-level because Dart handles media_processing.',
      );
    });
  });

  group('Apple audio-overlay diagnostic contract', () {
    test('exports curated outcomes without forwarding periodic ticks', () {
      final source = _appleAudioOverlaySourceFile().readAsStringSync();

      expect(source, isNot(contains('import os')));
      expect(source, contains('DivineVideoPlayerLog.shared'));
      expect(source, contains('trackIndex: index'));
      expect(source, contains('player.currentItem?.status'));
      expect(source, contains('player.currentItem?.error'));
      expect(source, contains('player.status'));
      expect(source, contains('seek completed='));
      expect(source, contains('skipping invalid uri'));
      expect(
        source,
        contains('print("[AudioOverlay] update: position'),
        reason:
            'The position trace stays on the console instead of the log '
            'bridge, so it cannot crowd state transitions and failures out '
            'of an exported bug report.',
      );
    });

    test('keeps console traces out of release builds', () {
      final source = _appleAudioOverlaySourceFile().readAsStringSync();

      expect(
        _printsOutsideDebugGuards(source),
        isEmpty,
        reason:
            'update() runs five times a second on the main queue for every '
            'player, and a console trace never reaches a bug report, so '
            'these traces must not ship in release builds.',
      );
    });
  });
}

/// Returns every `print(` in [source] that is not inside a `#if DEBUG` block.
List<String> _printsOutsideDebugGuards(String source) {
  final offenders = <String>[];
  final enclosingDebugGuards = <bool>[];
  final lines = source.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (line.startsWith('#if')) {
      enclosingDebugGuards.add(line == '#if DEBUG');
      continue;
    }
    if (line.startsWith('#else') || line.startsWith('#elseif')) {
      if (enclosingDebugGuards.isNotEmpty) {
        enclosingDebugGuards[enclosingDebugGuards.length - 1] = false;
      }
      continue;
    }
    if (line.startsWith('#endif')) {
      if (enclosingDebugGuards.isNotEmpty) {
        enclosingDebugGuards.removeLast();
      }
      continue;
    }

    if (line.startsWith('//') || !line.contains('print(')) continue;
    if (enclosingDebugGuards.contains(true)) continue;
    offenders.add('line ${i + 1}: $line');
  }

  return offenders;
}

File _androidSourceFile() {
  final packageRelative = File(
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
}

File _appleSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
}

File _appleAudioOverlaySourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'AudioOverlayManager.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'AudioOverlayManager.swift',
  );
}
