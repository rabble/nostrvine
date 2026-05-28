// ABOUTME: Unit tests for WatermarkDownloadProgressCubit — stage emits,
// ABOUTME: result emit, reset.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/watermark_download_progress/watermark_download_progress_cubit.dart';
import 'package:openvine/blocs/watermark_download_progress/watermark_download_progress_state.dart';
import 'package:openvine/services/watermark_download_service.dart';

class _MockService extends Mock implements WatermarkDownloadService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  group(WatermarkDownloadProgressCubit, () {
    late _MockService service;
    late VideoEvent video;

    setUpAll(() {
      registerFallbackValue(_FakeVideoEvent());
    });

    setUp(() {
      service = _MockService();
      video = _FakeVideoEvent();
    });

    WatermarkDownloadProgressCubit buildCubit() =>
        WatermarkDownloadProgressCubit(
          service: service,
          video: video,
          watermarkText: '@user',
        );

    blocTest<WatermarkDownloadProgressCubit, WatermarkDownloadProgressState>(
      'start emits stage progression then success result',
      build: buildCubit,
      setUp: () {
        when(
          () => service.downloadWithWatermark(
            video: any(named: 'video'),
            watermarkText: any(named: 'watermarkText'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as ValueChanged<WatermarkDownloadStage>;
          onProgress(WatermarkDownloadStage.watermarking);
          onProgress(WatermarkDownloadStage.saving);
          return const WatermarkDownloadSuccess('/tmp/v.mp4');
        });
      },
      act: (cubit) => cubit.start(),
      expect: () => [
        const WatermarkDownloadProgressState(
          stage: WatermarkDownloadStage.watermarking,
        ),
        const WatermarkDownloadProgressState(
          stage: WatermarkDownloadStage.saving,
        ),
        const WatermarkDownloadProgressState(
          stage: WatermarkDownloadStage.saving,
          result: WatermarkDownloadSuccess('/tmp/v.mp4'),
          isProcessing: false,
        ),
      ],
      verify: (_) {
        verify(
          () => service.downloadWithWatermark(
            video: any(named: 'video'),
            watermarkText: '@user',
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
      },
    );

    blocTest<WatermarkDownloadProgressCubit, WatermarkDownloadProgressState>(
      'reset clears state',
      seed: () => const WatermarkDownloadProgressState(
        stage: WatermarkDownloadStage.saving,
        result: WatermarkDownloadFailure('boom'),
        isProcessing: false,
      ),
      build: buildCubit,
      act: (cubit) => cubit.reset(),
      expect: () => [const WatermarkDownloadProgressState()],
    );
  });
}
