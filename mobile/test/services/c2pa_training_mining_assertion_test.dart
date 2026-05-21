// ABOUTME: Tests for CAWG training-mining assertion in C2PA manifests
// ABOUTME: Verifies the cawg.training-mining assertion is always embedded

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/c2pa_signing_service.dart';

void main() {
  group('C2PA training-mining assertion', () {
    late C2paSigningService service;

    setUp(() {
      service = C2paSigningService();
    });

    test('always includes cawg.training-mining assertion', () {
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

    test('emits c2pa.actions.v2 before cawg.training-mining', () {
      final manifest = service.buildManifestJsonPublic(
        'DiVine/1.0',
        'test.mp4',
        'https://example.com/digitalCapture',
      );

      final json = jsonDecode(manifest) as Map<String, dynamic>;
      final assertions = json['assertions'] as List<dynamic>;

      expect(
        (assertions[0] as Map<String, dynamic>)['label'],
        equals('c2pa.actions.v2'),
      );
      expect(
        (assertions[1] as Map<String, dynamic>)['label'],
        equals('cawg.training-mining'),
      );
    });
  });
}
