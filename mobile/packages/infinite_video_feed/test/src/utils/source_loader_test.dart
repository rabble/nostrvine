import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/source_loader.dart';

import '../../helpers/fake_controller.dart';

void main() {
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
      expect(logs, isEmpty);
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
