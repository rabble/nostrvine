import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/source_loader.dart';

import '../../helpers/fake_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setSourceWithFallbacks', () {
    final logs = <String>[];

    setUp(logs.clear);

    test('returns (source, 0) when first source succeeds', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['urlA', 'urlB'],
        log: logs.add,
      );

      expect(result, equals(('urlA', 0)));
      expect(controller.lastSource?.httpHeaders, isEmpty);
      expect(logs, isEmpty);
    });

    test('passes headers for the selected source', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['urlA'],
        log: logs.add,
        httpHeadersForSource: (source) =>
            source == 'urlA' ? {'Authorization': 'Nostr token'} : null,
      );

      expect(result, equals(('urlA', 0)));
      expect(
        controller.lastSource?.httpHeaders,
        equals({'Authorization': 'Nostr token'}),
      );
    });

    test('returns (nextSource, 1) and logs when first source fails', () async {
      final controller = _FakeControllerWithOneFailure();
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 1,
        controller: controller,
        sources: ['badUrl', 'goodUrl'],
        log: logs.add,
      );

      expect(result, equals(('goodUrl', 1)));
      expect(logs, hasLength(1));
      expect(logs.first, contains('badUrl'));
    });

    test(
      'applies the same headers to every source in the fallover chain',
      () async {
        final clips = <VideoClip>[];
        final controller = _RecordingControllerWithOneFailure(clips.add);
        addTearDown(controller.dispose);

        const headers = {'Authorization': 'Nostr token'};
        final result = await setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: ['optimizedUrl', 'hlsUrl'],
          log: logs.add,
          // Mirrors _httpHeadersByIndex: one hash-bound header set returned for
          // every resolved source, so the fallback authenticates too.
          httpHeadersForSource: (_) => headers,
        );

        expect(result, equals(('hlsUrl', 1)));
        expect(clips, hasLength(2));
        expect(clips[0].uri, 'optimizedUrl');
        expect(clips[0].httpHeaders, equals(headers));
        expect(clips[1].uri, 'hlsUrl');
        expect(clips[1].httpHeaders, equals(headers));
      },
    );

    test('uses headers returned for the successful failover source', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithOneFailure(clips.add);
      addTearDown(controller.dispose);

      const headers = {'Authorization': 'Nostr token'};
      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['anonymousUrl', 'authedUrl'],
        log: logs.add,
        httpHeadersForSource: (source) =>
            source == 'authedUrl' ? headers : null,
      );

      expect(result, equals(('authedUrl', 1)));
      expect(clips, hasLength(2));
      expect(clips[0].uri, 'anonymousUrl');
      expect(clips[0].httpHeaders, isEmpty);
      expect(clips[1].uri, 'authedUrl');
      expect(clips[1].httpHeaders, equals(headers));
    });

    test(
      'aborts stale fallback without logging all sources failed',
      () async {
        var isCurrent = true;
        final controller = _DisposedDuringFallbackController(
          onDisposedFallback: () => isCurrent = false,
        );
        addTearDown(controller.dispose);

        await expectLater(
          () => setSourceWithFallbacks(
            index: 0,
            controller: controller,
            sources: ['derivedMp4', 'hls', 'raw'],
            log: logs.add,
            isLoadCurrent: () => isCurrent,
          ),
          throwsA(isA<SourceLoadAborted>()),
        );

        expect(controller.attempts, equals(2));
        expect(logs, hasLength(1));
        expect(logs.single, contains('failedSource=derivedMp4'));
        expect(logs.single, contains('retrySource=hls'));
        expect(
          logs.any((line) => line.contains('All sources failed')),
          isFalse,
        );
      },
    );

    test(
      'aborts when the controller goes stale after a source opens',
      () async {
        var isCurrent = true;
        final controller = _StaleAfterSuccessController(
          onOpened: () => isCurrent = false,
        );
        addTearDown(controller.dispose);

        await expectLater(
          () => setSourceWithFallbacks(
            index: 3,
            controller: controller,
            sources: ['derivedMp4', 'hls', 'raw'],
            log: logs.add,
            isLoadCurrent: () => isCurrent,
          ),
          throwsA(
            isA<SourceLoadAborted>()
                .having((e) => e.index, 'index', 3)
                .having((e) => e.source, 'source', 'derivedMp4')
                .having(
                  (e) => e.toString(),
                  'message',
                  contains(
                    'Source load aborted for stale controller index 3 '
                    'source=derivedMp4',
                  ),
                ),
          ),
        );

        // Only the first source is attempted; the post-open staleness check
        // aborts before returning a record or trying any fallback.
        expect(controller.attempts, equals(1));
        expect(logs, isEmpty);
      },
    );

    test('rethrows when all sources fail', () async {
      final controller = FakeController()
        ..setSourceError = Exception('always fails');
      addTearDown(controller.dispose);

      await expectLater(
        () => setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: ['url1', 'url2'],
          log: logs.add,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws StateError when sources list is empty', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await expectLater(
        () => setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: [],
          log: logs.add,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'returns single source when only one provided and it succeeds',
      () async {
        final controller = FakeController();
        addTearDown(controller.dispose);

        final result = await setSourceWithFallbacks(
          index: 5,
          controller: controller,
          sources: ['onlyUrl'],
          log: logs.add,
        );

        expect(result, equals(('onlyUrl', 0)));
      },
    );
  });
}

/// A [FakeController] that fails only on the first [setSource] call.
class _FakeControllerWithOneFailure extends FakeController {
  var _failed = false;

  @override
  Future<void> setSource(VideoClip clip) async {
    if (!_failed) {
      _failed = true;
      throw Exception('first source error');
    }
  }
}

/// A [FakeController] that records every clip and fails only on the first
/// [setSource] call, so a fallover chain can be asserted clip-by-clip.
class _RecordingControllerWithOneFailure extends FakeController {
  _RecordingControllerWithOneFailure(this._record);

  final void Function(VideoClip) _record;
  var _failed = false;

  @override
  Future<void> setSource(VideoClip clip) async {
    _record(clip);
    if (!_failed) {
      _failed = true;
      throw Exception('first source error');
    }
  }
}

class _DisposedDuringFallbackController extends FakeController {
  _DisposedDuringFallbackController({required this.onDisposedFallback});

  final VoidCallback onDisposedFallback;
  int attempts = 0;

  @override
  Future<void> setSource(VideoClip clip) async {
    attempts++;
    if (attempts == 1) {
      throw Exception('HTTP 202 Accepted');
    }

    onDisposedFallback();
    throw StateError('Controller has been disposed.');
  }
}

/// A [FakeController] whose first [setSource] succeeds but marks the load
/// stale (e.g. the feed window scrolled past) before the caller can register
/// the opened source.
class _StaleAfterSuccessController extends FakeController {
  _StaleAfterSuccessController({required this.onOpened});

  final VoidCallback onOpened;
  int attempts = 0;

  @override
  Future<void> setSource(VideoClip clip) async {
    attempts++;
    onOpened();
  }
}
