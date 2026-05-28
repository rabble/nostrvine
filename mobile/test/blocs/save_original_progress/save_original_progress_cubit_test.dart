// ABOUTME: Unit tests for SaveOriginalProgressCubit — stage emits, result
// ABOUTME: emit on completion, reset.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/save_original_progress/save_original_progress_cubit.dart';
import 'package:openvine/blocs/save_original_progress/save_original_progress_state.dart';
import 'package:openvine/services/watermark_download_service.dart';

class _MockService extends Mock implements WatermarkDownloadService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  group(SaveOriginalProgressCubit, () {
    late _MockService service;
    late VideoEvent video;

    setUpAll(() {
      registerFallbackValue(_FakeVideoEvent());
    });

    setUp(() {
      service = _MockService();
      video = _FakeVideoEvent();
    });

    blocTest<SaveOriginalProgressCubit, SaveOriginalProgressState>(
      'start emits stage progression then success result',
      build: () => SaveOriginalProgressCubit(service: service, video: video),
      setUp: () {
        when(
          () => service.downloadOriginal(
            video: any(named: 'video'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as ValueChanged<OriginalSaveStage>;
          onProgress(OriginalSaveStage.saving);
          return const WatermarkDownloadSuccess('/tmp/v.mp4');
        });
      },
      act: (cubit) => cubit.start(),
      expect: () => [
        const SaveOriginalProgressState(stage: OriginalSaveStage.saving),
        const SaveOriginalProgressState(
          stage: OriginalSaveStage.saving,
          result: WatermarkDownloadSuccess('/tmp/v.mp4'),
          isProcessing: false,
        ),
      ],
    );

    blocTest<SaveOriginalProgressCubit, SaveOriginalProgressState>(
      'start emits permission-denied result',
      build: () => SaveOriginalProgressCubit(service: service, video: video),
      setUp: () {
        when(
          () => service.downloadOriginal(
            video: any(named: 'video'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const WatermarkDownloadPermissionDenied(),
        );
      },
      act: (cubit) => cubit.start(),
      expect: () => [
        const SaveOriginalProgressState(
          result: WatermarkDownloadPermissionDenied(),
          isProcessing: false,
        ),
      ],
    );

    blocTest<SaveOriginalProgressCubit, SaveOriginalProgressState>(
      'reset clears result and flips back to processing',
      seed: () => const SaveOriginalProgressState(
        stage: OriginalSaveStage.saving,
        result: WatermarkDownloadPermissionDenied(),
        isProcessing: false,
      ),
      build: () => SaveOriginalProgressCubit(service: service, video: video),
      act: (cubit) => cubit.reset(),
      expect: () => [const SaveOriginalProgressState()],
    );
  });
}
