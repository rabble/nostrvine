import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoIndexState', () {
    test('isLoading is true only for LoadState.loading', () {
      expect(
        const VideoIndexState(loadState: LoadState.loading).isLoading,
        isTrue,
      );
      expect(
        const VideoIndexState().isLoading,
        isFalse,
      );
      expect(
        const VideoIndexState(loadState: LoadState.ready).isLoading,
        isFalse,
      );
      expect(
        const VideoIndexState(loadState: LoadState.error).isLoading,
        isFalse,
      );
    });
  });
}
