// ABOUTME: Static guards for the iOS mic-level re-settle before capture.
// ABOUTME: The override must stay scoped to a speaker-only output route.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

/// Returns the `else` block belonging to the `if` that starts at [signature].
///
/// Pins which branch a call sits in: an assertion scoped to the declaration
/// alone would stay green if the call moved into the other branch.
String _elseBlockOf(String source, String signature) {
  final ifBlock = declarationAt(source, signature);
  final afterIf = source.substring(
    source.indexOf(ifBlock) + ifBlock.length,
  );

  return declarationAt(afterIf, ' else {');
}

void main() {
  group('iOS capture input level re-settle', () {
    late final String startRecording;
    late final String audioReadyBranch;
    late final String resettleHelper;

    setUpAll(() {
      final controllerSource = readNativeSource('CameraController.swift');
      startRecording = declarationAt(
        controllerSource,
        'func startRecording(maxDurationMs:',
      );
      audioReadyBranch = _elseBlockOf(startRecording, 'if !audioReady {');
      resettleHelper = declarationAt(
        controllerSource,
        'private func resettleSpeakerRouteBeforeCapture(',
      );
    });

    test('record start re-settles the route once audio is ready', () {
      // iOS damps the mic input while the countdown beeps play out of the
      // speaker and restores it only slowly, so capture would otherwise
      // start on a damped input and climb back over several seconds. The
      // branch matters: on the !audioReady side there is no audio track to
      // rescue, and the call would only move the route for nothing.
      expect(
        audioReadyBranch,
        contains('self.resettleSpeakerRouteBeforeCapture()'),
      );
      expect(
        resettleHelper,
        contains('try session.overrideOutputAudioPort(.speaker)'),
      );
    });

    test('the re-settle runs before the writer starts', () {
      // "Before capture" is the contract: once the writer is running, an
      // override no longer rescues the damped input the beeps left behind,
      // it only changes the route mid-clip.
      final resettleCall = startRecording.indexOf(
        'self.resettleSpeakerRouteBeforeCapture()',
      );
      final writerStart = startRecording.indexOf(
        'self.startRecordingAfterAudioReady(',
      );
      expect(resettleCall, isNonNegative);
      expect(writerStart, isNonNegative);
      expect(resettleCall, lessThan(writerStart));
    });

    test('the override stays scoped to a speaker-only route', () {
      // Overriding while headphones or Bluetooth are connected would drag
      // playback off them, and no speaker output reached the mic anyway.
      final guard = resettleHelper.indexOf(
        'guard outputs.count == 1, outputs[0].portType == .builtInSpeaker',
      );
      final override = resettleHelper.indexOf(
        'try session.overrideOutputAudioPort(.speaker)',
      );
      expect(guard, isNonNegative);
      expect(override, greaterThan(guard));
    });

    test('a failed override does not abort the recording', () {
      expect(resettleHelper, contains('catch'));
      expect(resettleHelper, isNot(contains('throw')));
    });
  });
}
