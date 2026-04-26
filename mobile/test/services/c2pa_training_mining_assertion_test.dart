// ABOUTME: Tests for CAWG training-mining assertion in C2PA manifests
// ABOUTME: Verifies the cawg.training-mining assertion is correctly embedded

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/c2pa_signing_service.dart';

void main() {
  group('C2PA training-mining assertion', () {
    late C2paSigningService service;

    setUp(() {
      service = C2paSigningService();
    });

    test('includes cawg.training-mining assertion when opt-out is enabled', () {
      final manifest = service.buildManifestJsonPublic(
        'DiVine/1.0',
        'test.mp4',
        'https://example.com/digitalCapture',
      );

      final json = jsonDecode(manifest) as Map<String, dynamic>;
      final assertions = json['assertions'] as List<dynamic>;

      expect(assertions, hasLength(2));

      final trainingAssertion = assertions[1] as Map<String, dynamic>;
      expect(trainingAssertion['label'], equals('cawg.training-mining'));

      final data = trainingAssertion['data'] as Map<String, dynamic>;
      final entries = data['entries'] as Map<String, dynamic>;

      expect(entries, hasLength(4));

      for (final key in [
        'cawg.ai_training',
        'cawg.ai_inference',
        'cawg.ai_generative_training',
        'cawg.data_mining',
      ]) {
        final entry = entries[key] as Map<String, dynamic>;
        expect(
          entry['use'],
          equals('notAllowed'),
          reason: '$key should be notAllowed',
        );
      }
    });

    test(
      'excludes cawg.training-mining assertion when opt-out is disabled',
      () {
        final manifest = service.buildManifestJsonPublic(
          'DiVine/1.0',
          'test.mp4',
          'https://example.com/digitalCapture',
          aiTrainingOptOut: false,
        );

        final json = jsonDecode(manifest) as Map<String, dynamic>;
        final assertions = json['assertions'] as List<dynamic>;

        expect(assertions, hasLength(1));
        expect(
          (assertions[0] as Map<String, dynamic>)['label'],
          equals('c2pa.actions.v2'),
        );
      },
    );

    test('always includes c2pa.actions.v2 assertion regardless of opt-out', () {
      for (final optOut in [true, false]) {
        final manifest = service.buildManifestJsonPublic(
          'DiVine/1.0',
          'test.mp4',
          'https://example.com/digitalCapture',
          aiTrainingOptOut: optOut,
        );

        final json = jsonDecode(manifest) as Map<String, dynamic>;
        final assertions = json['assertions'] as List<dynamic>;
        final actionsAssertion = assertions[0] as Map<String, dynamic>;

        expect(actionsAssertion['label'], equals('c2pa.actions.v2'));
      }
    });
  });
}
