import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/c2pa_signing_service.dart';

class _MockC2paSigningService extends Mock implements C2paSigningService {}

void main() {
  late C2paImportValidationService service;
  late _MockC2paSigningService mockC2paSigningService;

  setUp(() {
    mockC2paSigningService = _MockC2paSigningService();
    service = C2paImportValidationService(
      c2paSigningService: mockC2paSigningService,
    );
  });

  group(C2paImportValidationService, () {
    group('validateFile', () {
      test('returns noCredentials when manifest is null', () async {
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenAnswer((_) async => null);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.noCredentials));
      });

      test('returns noCredentials when active manifest is null', () async {
        const manifestInfo = ManifestStoreInfo();
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.noCredentials));
      });

      test('returns verified for digitalCapture source type', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'diVine/2.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture',
          validationStatus: ValidationStatus.valid,
          issuer: 'Guardian Project',
        );
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.verified));
        expect(result.claimGenerator, equals('diVine/2.0'));
        expect(
          result.digitalSourceType,
          equals(C2paSourceClassification.humanCreated),
        );
        expect(result.signatureIssuer, equals('Guardian Project'));
      });

      test('returns verified for digitalCreation source type', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
          validationStatus: ValidationStatus.valid,
          issuer: 'Adobe Inc.',
          title: 'My Animation',
        );
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.verified));
        expect(result.sourceAppName, equals('Adobe Fresco'));
        expect(result.title, equals('My Animation'));
      });

      test('returns aiGenerated for trainedAlgorithmicMedia', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'Adobe Photoshop/25.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/'
              'trainedAlgorithmicMedia',
          validationStatus: ValidationStatus.valid,
        );
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.aiGenerated));
      });

      test(
        'returns aiGenerated for compositeWithTrainedAlgorithmicMedia',
        () async {
          final manifestInfo = _buildManifestStoreInfo(
            claimGenerator: 'Adobe Fresco/5.0',
            digitalSourceTypeUrl:
                'http://cv.iptc.org/newscodes/digitalsourcetype/'
                'compositeWithTrainedAlgorithmicMedia',
            validationStatus: ValidationStatus.valid,
          );
          when(
            () => mockC2paSigningService.readManifest(any()),
          ).thenAnswer((_) async => manifestInfo);

          final result = await service.validateFile('/path/to/video.mp4');

          expect(result.status, equals(C2paImportStatus.aiGenerated));
        },
      );

      test('returns invalidSignature when validation fails', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'SomeApp/1.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture',
          validationStatus: ValidationStatus.invalid,
        );
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.invalidSignature));
      });

      test('returns error when readManifest throws', () async {
        when(
          () => mockC2paSigningService.readManifest(any()),
        ).thenThrow(Exception('corrupt file'));

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.error));
        expect(result.rejectionReason, contains('corrupt file'));
      });

      test(
        'returns verified with unknown source when no actions assertion',
        () async {
          const manifestLabel = 'test:manifest';
          const manifestInfo = ManifestStoreInfo(
            activeManifest: manifestLabel,
            validationStatus: ValidationStatus.valid,
            manifests: {
              manifestLabel: ManifestInfo(
                label: manifestLabel,
                claimGenerator: 'TestApp/1.0',
              ),
            },
          );
          when(
            () => mockC2paSigningService.readManifest(any()),
          ).thenAnswer((_) async => manifestInfo);

          final result = await service.validateFile('/path/to/video.mp4');

          expect(result.status, equals(C2paImportStatus.verified));
          expect(
            result.digitalSourceType,
            equals(C2paSourceClassification.unknown),
          );
        },
      );
    });
  });
}

ManifestStoreInfo _buildManifestStoreInfo({
  required String claimGenerator,
  required String digitalSourceTypeUrl,
  required ValidationStatus validationStatus,
  String? issuer,
  String? title,
}) {
  const manifestLabel = 'test:manifest';
  return ManifestStoreInfo(
    activeManifest: manifestLabel,
    validationStatus: validationStatus,
    manifests: {
      manifestLabel: ManifestInfo(
        label: manifestLabel,
        claimGenerator: claimGenerator,
        title: title,
        signature: SignatureInfo(issuer: issuer),
        assertions: [
          AssertionInfo(
            label: 'c2pa.actions',
            data: {
              'actions': [
                {'digitalSourceType': digitalSourceTypeUrl},
              ],
            },
          ),
        ],
      ),
    },
  );
}
