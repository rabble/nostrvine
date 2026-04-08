import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/c2pa_import_result.dart';

void main() {
  group(C2paImportResult, () {
    group('factory constructors', () {
      test('creates verified result with all fields', () {
        final result = C2paImportResult.verified(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceType: C2paSourceClassification.humanCreated,
          digitalSourceTypeRaw:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
          signatureIssuer: 'Adobe Inc.',
          signedAt: DateTime.utc(2026, 4, 8),
          title: 'My Animation',
        );
        expect(result.status, equals(C2paImportStatus.verified));
        expect(result.claimGenerator, equals('Adobe Fresco/5.0'));
        expect(
          result.digitalSourceType,
          equals(C2paSourceClassification.humanCreated),
        );
        expect(result.signatureIssuer, equals('Adobe Inc.'));
        expect(result.title, equals('My Animation'));
        expect(result.rejectionReason, isNull);
      });

      test('creates noCredentials result', () {
        final result = C2paImportResult.noCredentials();
        expect(result.status, equals(C2paImportStatus.noCredentials));
        expect(result.claimGenerator, isNull);
        expect(result.digitalSourceType, isNull);
      });

      test('creates aiGenerated result', () {
        final result = C2paImportResult.aiGenerated(
          claimGenerator: 'Adobe Photoshop/25.0',
          digitalSourceTypeRaw:
              'http://cv.iptc.org/newscodes/digitalsourcetype/'
              'trainedAlgorithmicMedia',
        );
        expect(result.status, equals(C2paImportStatus.aiGenerated));
        expect(result.claimGenerator, equals('Adobe Photoshop/25.0'));
        expect(
          result.digitalSourceType,
          equals(C2paSourceClassification.aiGenerated),
        );
      });

      test('creates invalidSignature result', () {
        final result = C2paImportResult.invalidSignature();
        expect(result.status, equals(C2paImportStatus.invalidSignature));
      });

      test('creates error result with rejection reason', () {
        final result = C2paImportResult.error('corrupt file');
        expect(result.status, equals(C2paImportStatus.error));
        expect(result.rejectionReason, equals('corrupt file'));
      });
    });

    group('computed properties', () {
      test('isAccepted returns true only for verified status', () {
        expect(
          C2paImportResult.verified(
            claimGenerator: 'Test/1.0',
            digitalSourceType: C2paSourceClassification.humanCreated,
            digitalSourceTypeRaw: 'http://example.com',
          ).isAccepted,
          isTrue,
        );
        expect(C2paImportResult.noCredentials().isAccepted, isFalse);
        expect(C2paImportResult.aiGenerated().isAccepted, isFalse);
        expect(C2paImportResult.invalidSignature().isAccepted, isFalse);
        expect(C2paImportResult.error('test').isAccepted, isFalse);
      });

      test('sourceAppName extracts app name before slash', () {
        final result = C2paImportResult.verified(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceType: C2paSourceClassification.humanCreated,
          digitalSourceTypeRaw: 'http://example.com',
        );
        expect(result.sourceAppName, equals('Adobe Fresco'));
      });

      test('sourceAppName returns null when claimGenerator is null', () {
        expect(C2paImportResult.noCredentials().sourceAppName, isNull);
      });
    });
  });

  group(C2paSourceClassification, () {
    test('classifies human-created source types', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture',
        ),
        equals(C2paSourceClassification.humanCreated),
      );
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
        ),
        equals(C2paSourceClassification.humanCreated),
      );
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/humanEdits',
        ),
        equals(C2paSourceClassification.humanCreated),
      );
    });

    test('classifies AI-generated source types', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/'
          'trainedAlgorithmicMedia',
        ),
        equals(C2paSourceClassification.aiGenerated),
      );
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/'
          'trainedAlgorithmicData',
        ),
        equals(C2paSourceClassification.aiGenerated),
      );
    });

    test('classifies composite source types', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/'
          'compositeWithTrainedAlgorithmicMedia',
        ),
        equals(C2paSourceClassification.compositeWithAi),
      );
    });

    test('returns unknown for unrecognized URLs', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://example.com/unknown',
        ),
        equals(C2paSourceClassification.unknown),
      );
    });

    test('returns unknown for null URL', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(null),
        equals(C2paSourceClassification.unknown),
      );
    });
  });
}
