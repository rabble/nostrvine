import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/video_import_service.dart';

class _MockC2paImportValidationService extends Mock
    implements C2paImportValidationService {}

class _MockVideoImportService extends Mock implements VideoImportService {}

void main() {
  late _MockC2paImportValidationService mockValidationService;
  late _MockVideoImportService mockImportService;

  setUpAll(() {
    registerFallbackValue(C2paImportResult.noCredentials());
  });

  setUp(() {
    mockValidationService = _MockC2paImportValidationService();
    mockImportService = _MockVideoImportService();
  });

  VideoImportBloc buildBloc() => VideoImportBloc(
    validationService: mockValidationService,
    importService: mockImportService,
  );

  group(VideoImportBloc, () {
    group('VideoImportReceived', () {
      final verifiedResult = C2paImportResult.verified(
        claimGenerator: 'Adobe Fresco/5.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw:
            'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
        signatureIssuer: 'Adobe Inc.',
        title: 'My Animation',
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [validating, verified] when C2PA validation succeeds',
        setUp: () {
          when(
            () => mockValidationService.validateFile(any()),
          ).thenAnswer((_) async => verifiedResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoImportReceived(filePath: '/path/to/video.mp4'),
        ),
        expect: () => [
          const VideoImportState(
            status: VideoImportStatus.validating,
            filePath: '/path/to/video.mp4',
          ),
          VideoImportState(
            status: VideoImportStatus.verified,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
        ],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [validating, rejected] when no C2PA credentials',
        setUp: () {
          when(
            () => mockValidationService.validateFile(any()),
          ).thenAnswer((_) async => C2paImportResult.noCredentials());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoImportReceived(filePath: '/path/to/video.mp4'),
        ),
        expect: () => [
          const VideoImportState(
            status: VideoImportStatus.validating,
            filePath: '/path/to/video.mp4',
          ),
          VideoImportState(
            status: VideoImportStatus.rejected,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.noCredentials(),
          ),
        ],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [validating, rejected] when AI-generated',
        setUp: () {
          when(() => mockValidationService.validateFile(any())).thenAnswer(
            (_) async => C2paImportResult.aiGenerated(
              claimGenerator: 'Adobe Photoshop/25.0',
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoImportReceived(filePath: '/path/to/video.mp4'),
        ),
        expect: () => [
          const VideoImportState(
            status: VideoImportStatus.validating,
            filePath: '/path/to/video.mp4',
          ),
          VideoImportState(
            status: VideoImportStatus.rejected,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.aiGenerated(
              claimGenerator: 'Adobe Photoshop/25.0',
            ),
          ),
        ],
      );
    });

    group('VideoImportConfirmed', () {
      final verifiedResult = C2paImportResult.verified(
        claimGenerator: 'Adobe Fresco/5.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw:
            'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [importing, imported] when import succeeds',
        setUp: () {
          when(
            () => mockImportService.importVerifiedVideo(
              filePath: any(named: 'filePath'),
              validationResult: any(named: 'validationResult'),
            ),
          ).thenAnswer((_) async => 'draft-123');
        },
        build: buildBloc,
        seed: () => VideoImportState(
          status: VideoImportStatus.verified,
          filePath: '/path/to/video.mp4',
          validationResult: verifiedResult,
        ),
        act: (bloc) => bloc.add(const VideoImportConfirmed()),
        expect: () => [
          VideoImportState(
            status: VideoImportStatus.importing,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
          VideoImportState(
            status: VideoImportStatus.imported,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
            draftId: 'draft-123',
          ),
        ],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'does nothing when not in verified state',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoImportConfirmed()),
        expect: () => <VideoImportState>[],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [importing, error] when import throws',
        setUp: () {
          when(
            () => mockImportService.importVerifiedVideo(
              filePath: any(named: 'filePath'),
              validationResult: any(named: 'validationResult'),
            ),
          ).thenThrow(Exception('disk full'));
        },
        build: buildBloc,
        seed: () => VideoImportState(
          status: VideoImportStatus.verified,
          filePath: '/path/to/video.mp4',
          validationResult: verifiedResult,
        ),
        act: (bloc) => bloc.add(const VideoImportConfirmed()),
        expect: () => [
          VideoImportState(
            status: VideoImportStatus.importing,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
          VideoImportState(
            status: VideoImportStatus.error,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('VideoImportDismissed', () {
      blocTest<VideoImportBloc, VideoImportState>(
        'resets to initial state',
        build: buildBloc,
        seed: () => const VideoImportState(
          status: VideoImportStatus.rejected,
          filePath: '/path/to/video.mp4',
        ),
        act: (bloc) => bloc.add(const VideoImportDismissed()),
        expect: () => [const VideoImportState()],
      );
    });
  });
}
