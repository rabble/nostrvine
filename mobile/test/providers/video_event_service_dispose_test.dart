// ABOUTME: Regression test for #6174 — videoEventServiceProvider must dispose
// ABOUTME: the VideoEventService it created when the provider state is torn down.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_providers.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('videoEventServiceProvider disposal (#6174)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: getStandardTestOverrides().cast(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('disposes the previous service when the provider rebuilds', () {
      final first = container.read(videoEventServiceProvider);

      // A NostrService client swap (auth cold start, account switch)
      // invalidates the provider; the orphaned service must be disposed so
      // its periodic timers and auth subscription stop running against the
      // already-disposed EventRouter.
      container.invalidate(videoEventServiceProvider);
      final second = container.read(videoEventServiceProvider);

      expect(identical(first, second), isFalse);
      expect(
        () => first.addListener(() {}),
        throwsFlutterError,
        reason:
            'the replaced VideoEventService must be disposed; a live '
            'ChangeNotifier here means orphaned timers keep firing',
      );
    });

    test('disposes the service when the container is torn down', () {
      final service = container.read(videoEventServiceProvider);

      container.dispose();
      container = ProviderContainer(
        overrides: getStandardTestOverrides().cast(),
      );

      expect(() => service.addListener(() {}), throwsFlutterError);
    });
  });
}
