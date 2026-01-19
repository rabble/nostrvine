import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/src/models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  group('NostrClientConfig', () {
    late NostrSigner mockSigner;

    setUp(() {
      mockSigner = MockNostrSigner();
    });

    group('constructor', () {
      test('creates config with only signer', () {
        final config = NostrClientConfig(
          signer: mockSigner,
        );

        expect(config.signer, equals(mockSigner));
        expect(config.eventFilters, isEmpty);
        expect(config.onNotice, isNull);
        expect(config.gatewayUrl, isNull);
        expect(config.enableGateway, isFalse);
      });

      test('creates config with all fields', () {
        void noticeCallback(String relay, String message) {}
        const eventFilters = <EventFilter>[];

        final config = NostrClientConfig(
          signer: mockSigner,
          // easier to verify that the values are set correctly
          // ignore: avoid_redundant_argument_values
          eventFilters: eventFilters,
          onNotice: noticeCallback,
          gatewayUrl: 'https://gateway.example.com',
          enableGateway: true,
        );

        expect(config.signer, equals(mockSigner));
        expect(config.eventFilters, equals(eventFilters));
        expect(config.onNotice, equals(noticeCallback));
        expect(config.gatewayUrl, equals('https://gateway.example.com'));
        expect(config.enableGateway, isTrue);
      });

      test('uses default values for optional fields', () {
        final config = NostrClientConfig(
          signer: mockSigner,
        );

        expect(config.eventFilters, isEmpty);
        expect(config.onNotice, isNull);
        expect(config.gatewayUrl, isNull);
        expect(config.enableGateway, isFalse);
      });
    });
  });
}
