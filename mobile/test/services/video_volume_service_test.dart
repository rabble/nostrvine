import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_volume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoVolumeService, () {
    late VideoVolumeService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      service = VideoVolumeService.forTesting();
    });

    group('initial state', () {
      test('defaults volume to 1.0', () {
        expect(service.volume, equals(1.0));
      });

      test('defaults isMuted to false', () {
        expect(service.isMuted, isFalse);
      });

      test('respects initialVolume parameter', () {
        final muted = VideoVolumeService.forTesting(initialVolume: 0);
        expect(muted.volume, equals(0.0));
        expect(muted.isMuted, isTrue);
      });
    });

    group('onPlaybackVolumeChanged', () {
      test('updates volume', () {
        service.onPlaybackVolumeChanged(0);
        expect(service.volume, equals(0.0));
        expect(service.isMuted, isTrue);
      });

      test('persists volume to SharedPreferences', () async {
        service.onPlaybackVolumeChanged(0);

        // Allow the async _persist to complete.
        await Future<void>.delayed(Duration.zero);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('video_playback_volume'), equals(0.0));
      });

      test('does not notify listeners', () {
        var notified = false;
        service.addListener(() => notified = true);

        service.onPlaybackVolumeChanged(0);

        expect(notified, isFalse);
      });

      test('no-ops when volume is unchanged', () async {
        service.onPlaybackVolumeChanged(1);

        await Future<void>.delayed(Duration.zero);

        final prefs = await SharedPreferences.getInstance();
        // Key was never written because the value didn't change.
        expect(prefs.getDouble('video_playback_volume'), isNull);
      });
    });

    group('simulateSystemVolumeChange', () {
      test('mutes when system volume drops to zero', () {
        service.simulateSystemVolumeChange(0);

        expect(service.volume, equals(0.0));
        expect(service.isMuted, isTrue);
      });

      test('notifies listeners when muting', () {
        var notified = false;
        service.addListener(() => notified = true);

        service.simulateSystemVolumeChange(0);

        expect(notified, isTrue);
      });

      test('unmutes when system volume rises above zero', () {
        // Start muted.
        service.onPlaybackVolumeChanged(0);

        service.simulateSystemVolumeChange(0.5);

        expect(service.volume, equals(1.0));
        expect(service.isMuted, isFalse);
      });

      test('notifies listeners when unmuting', () {
        service.onPlaybackVolumeChanged(0);

        var notified = false;
        service.addListener(() => notified = true);

        service.simulateSystemVolumeChange(0.5);

        expect(notified, isTrue);
      });

      test('no-ops when system volume changes but state unchanged', () {
        // Volume is 1.0, system goes from 0.8 to 0.5 — still > 0, no change.
        var notified = false;
        service.addListener(() => notified = true);

        service.simulateSystemVolumeChange(0.5);

        expect(notified, isFalse);
        expect(service.volume, equals(1.0));
      });

      test('no-ops when already muted and system is zero', () {
        service.onPlaybackVolumeChanged(0);

        var notified = false;
        service.addListener(() => notified = true);

        service.simulateSystemVolumeChange(0);

        expect(notified, isFalse);
      });

      test('persists when muting', () async {
        service.simulateSystemVolumeChange(0);

        await Future<void>.delayed(Duration.zero);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('video_playback_volume'), equals(0.0));
      });

      test('persists when unmuting', () async {
        service.onPlaybackVolumeChanged(0);
        await Future<void>.delayed(Duration.zero);

        service.simulateSystemVolumeChange(0.7);
        await Future<void>.delayed(Duration.zero);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('video_playback_volume'), equals(1.0));
      });
    });

    group('dispose', () {
      test('can be called without error', () {
        expect(service.dispose, returnsNormally);
      });
    });
  });
}
