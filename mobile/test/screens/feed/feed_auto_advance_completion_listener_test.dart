// ABOUTME: Unit tests for FeedAutoAdvanceCompletionListener loop-boundary detection
// ABOUTME: Covers arming, firing, re-subscription on widget updates, and dispose

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/screens/feed/feed_auto_advance_completion_listener.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _PlayerHarness {
  _PlayerHarness({this.duration = const Duration(seconds: 5)}) {
    when(() => _player.stream).thenReturn(_stream);
    when(() => _player.state).thenReturn(_state);
    when(() => _stream.position).thenAnswer((_) => _positions.stream);
    when(() => _state.duration).thenReturn(duration);
    when(() => _state.position).thenReturn(Duration.zero);
  }

  final _MockPlayer _player = _MockPlayer();
  final _MockPlayerStream _stream = _MockPlayerStream();
  final _MockPlayerState _state = _MockPlayerState();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final Duration duration;

  Player get player => _player;

  void emit(Duration position) => _positions.add(position);

  Future<void> dispose() => _positions.close();
}

Widget _subject({
  required Player? player,
  required VoidCallback onCompleted,
  bool isEnabled = true,
  Duration startThreshold = const Duration(seconds: 1),
  Duration endThreshold = const Duration(seconds: 1),
  Key? listenerKey,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: FeedAutoAdvanceCompletionListener(
      key: listenerKey,
      player: player,
      isEnabled: isEnabled,
      onCompleted: onCompleted,
      startThreshold: startThreshold,
      endThreshold: endThreshold,
      child: const SizedBox.shrink(),
    ),
  );
}

Future<void> _flush(WidgetTester tester) async {
  // Allow the broadcast stream to deliver pending events.
  await tester.pump(Duration.zero);
}

void main() {
  group(FeedAutoAdvanceCompletionListener, () {
    late _PlayerHarness harness;
    late int completions;

    setUp(() {
      harness = _PlayerHarness();
      completions = 0;
    });

    tearDown(() async {
      await harness.dispose();
    });

    testWidgets(
      'fires onCompleted when player crosses loop boundary after arming',
      (tester) async {
        await tester.pumpWidget(
          _subject(player: harness.player, onCompleted: () => completions++),
        );

        // Normal forward progress — not near end yet, not armed.
        harness.emit(const Duration(seconds: 2));
        await _flush(tester);
        expect(completions, equals(0));

        // Crosses end threshold → arms.
        harness.emit(const Duration(milliseconds: 4500));
        await _flush(tester);
        expect(completions, equals(0));

        // Player loops to start → crossing fires exactly once.
        harness.emit(const Duration(milliseconds: 200));
        await _flush(tester);
        expect(completions, equals(1));

        // Subsequent ticks inside start threshold do not re-fire because
        // arming is cleared.
        harness.emit(const Duration(milliseconds: 400));
        await _flush(tester);
        expect(completions, equals(1));
      },
    );

    testWidgets('does not fire onCompleted when disabled', (tester) async {
      await tester.pumpWidget(
        _subject(
          player: harness.player,
          isEnabled: false,
          onCompleted: () => completions++,
        ),
      );

      // No subscription was installed while disabled, so these ticks
      // are irrelevant — assert the stream has no listener.
      expect(harness._positions.hasListener, isFalse);

      // Even if we push values, the listener is not attached.
      harness.emit(const Duration(milliseconds: 4500));
      harness.emit(const Duration(milliseconds: 200));
      await _flush(tester);
      expect(completions, equals(0));
    });

    testWidgets('does not fire onCompleted on a forward seek without arming', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(player: harness.player, onCompleted: () => completions++),
      );

      // Jump back to start without ever crossing the end threshold.
      harness.emit(const Duration(seconds: 2));
      harness.emit(const Duration(milliseconds: 100));
      await _flush(tester);
      expect(completions, equals(0));
    });

    testWidgets('does not fire onCompleted when player has zero duration', (
      tester,
    ) async {
      final zeroHarness = _PlayerHarness(duration: Duration.zero);
      addTearDown(zeroHarness.dispose);

      await tester.pumpWidget(
        _subject(player: zeroHarness.player, onCompleted: () => completions++),
      );

      zeroHarness.emit(const Duration(milliseconds: 100));
      zeroHarness.emit(Duration.zero);
      await _flush(tester);
      expect(completions, equals(0));
    });

    testWidgets('re-subscribes when the player reference changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(player: harness.player, onCompleted: () => completions++),
      );

      expect(harness._positions.hasListener, isTrue);

      final replacement = _PlayerHarness();
      addTearDown(replacement.dispose);

      await tester.pumpWidget(
        _subject(player: replacement.player, onCompleted: () => completions++),
      );

      expect(harness._positions.hasListener, isFalse);
      expect(replacement._positions.hasListener, isTrue);

      // The new player completes — fires from the new subscription.
      replacement.emit(const Duration(milliseconds: 4500));
      replacement.emit(const Duration(milliseconds: 200));
      await _flush(tester);
      expect(completions, equals(1));
    });

    testWidgets('cancels the subscription when disabled after being enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(player: harness.player, onCompleted: () => completions++),
      );
      expect(harness._positions.hasListener, isTrue);

      await tester.pumpWidget(
        _subject(
          player: harness.player,
          isEnabled: false,
          onCompleted: () => completions++,
        ),
      );
      expect(harness._positions.hasListener, isFalse);
    });

    testWidgets('clears arming when the player reference changes mid-flight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(player: harness.player, onCompleted: () => completions++),
      );

      // Arm via old player.
      harness.emit(const Duration(milliseconds: 4500));
      await _flush(tester);

      final replacement = _PlayerHarness();
      addTearDown(replacement.dispose);

      await tester.pumpWidget(
        _subject(player: replacement.player, onCompleted: () => completions++),
      );

      // A start-near position on the new player should NOT fire, because
      // arming was reset on re-subscription.
      replacement.emit(const Duration(milliseconds: 200));
      await _flush(tester);
      expect(completions, equals(0));
    });

    testWidgets('cancels the subscription on dispose', (tester) async {
      await tester.pumpWidget(
        _subject(player: harness.player, onCompleted: () => completions++),
      );
      expect(harness._positions.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(harness._positions.hasListener, isFalse);
    });

    testWidgets('tolerates player.state access throwing on initial sync', (
      tester,
    ) async {
      final throwingPlayer = _MockPlayer();
      final throwingState = _MockPlayerState();
      final throwingStream = _MockPlayerStream();
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);

      when(() => throwingPlayer.stream).thenReturn(throwingStream);
      when(() => throwingPlayer.state).thenReturn(throwingState);
      when(() => throwingStream.position).thenAnswer((_) => positions.stream);
      when(() => throwingState.position).thenThrow(StateError('boom'));
      when(() => throwingState.duration).thenReturn(const Duration(seconds: 5));

      await tester.pumpWidget(
        _subject(player: throwingPlayer, onCompleted: () => completions++),
      );

      // Subscription still installed; should behave like a fresh player.
      expect(positions.hasListener, isTrue);

      positions.add(const Duration(milliseconds: 4500));
      positions.add(const Duration(milliseconds: 200));
      await _flush(tester);
      expect(completions, equals(1));
    });

    testWidgets('does not fire onCompleted when player is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(player: null, onCompleted: () => completions++),
      );

      // No ticks possible without a player — verify the listener is
      // inert rather than crashing.
      expect(completions, equals(0));
    });
  });
}
