// ABOUTME: Tests for BlossomUploadService ProofMode header integration
// ABOUTME: Verifies _addProofModeHeaders correctly handles String and Map
//          values for pgpSignature, deviceAttestation, and c2pa_manifest_id

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

class _MockDio extends Mock implements Dio {}

class _MockFile extends Mock implements File {}

class _MockResponse extends Mock implements Response<dynamic> {}

const _testPubkey =
    '04c106a7b7b1ac0a26f0e2ad22aaa2cfc3263bb7749a165545689282d1975c23';

const _pgpSignatureString =
    '-----BEGIN PGP SIGNATURE-----\n'
    'Version: BCPG v1.71\n'
    '\n'
    'iQIcBAABCAAGBQJpw5g6AAoJEJf6B+TEST1234\n'
    '=abcd\n'
    '-----END PGP SIGNATURE-----\n';

/// SHA-256 hash of `[1, 2, 3]`.
const _sha256Of123 =
    '039058c6f2c0cb492c533b0a4d14ef77'
    'cc0f78abccced5287d84a1a2011cfb81';

const _deviceAttestationString =
    'Certificate:\n'
    '    Data:\n'
    '        Version: 3 (0x2)\n'
    '        Serial Number: 1 (0x1)\n'
    '    Signature Algorithm: ecdsa-with-SHA256\n'
    '        Issuer: O=TEE, CN=test\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(Options());
    registerFallbackValue(<String, String>{});
  });

  group(BlossomUploadService, () {
    late BlossomUploadService service;
    late _MockAuthProvider mockAuthProvider;
    late _MockDio mockDio;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LogCaptureService().clearAllLogs();
      mockAuthProvider = _MockAuthProvider();
      mockDio = _MockDio();
      service = BlossomUploadService(
        authProvider: mockAuthProvider,
        dio: mockDio,
      );
    });

    tearDown(() async {
      await LogCaptureService().clearAllLogs();
    });

    Options? capturedOptions;

    /// Sets up mocks for a video upload and captures the [Options] passed
    /// to `dio.put` so tests can inspect the headers.
    void arrangeUploadMocks() {
      capturedOptions = null;

      when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

      when(
        () => mockAuthProvider.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => const BlossomSignedEvent(
          json: {
            'id': 'test_id',
            'pubkey': _testPubkey,
            'created_at': 0,
            'kind': 24242,
            'tags': [
              ['t', 'upload'],
              ['expiration', '9999999999'],
              ['size', '3'],
              ['x', _sha256Of123],
            ],
            'content': 'Upload to Blossom',
            'sig': 'test_sig',
          },
        ),
      );

      final mockResponse = _MockResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.headers).thenReturn(Headers());
      when(() => mockResponse.data).thenReturn(<String, dynamic>{
        'url': 'https://media.divine.video/abc123',
        'sha256': 'abc123',
        'size': 3,
        'type': 'video/mp4',
      });

      when(
        () => mockDio.head<dynamic>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 200,
          headers: Headers(),
        ),
      );

      when(
        () => mockDio.put<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((invocation) async {
        capturedOptions =
            invocation.namedArguments[const Symbol('options')] as Options?;
        return mockResponse;
      });
    }

    File createMockFile() {
      final mockFile = _MockFile();
      when(() => mockFile.path).thenReturn('/test/video.mp4');
      when(mockFile.existsSync).thenReturn(true);
      when(
        mockFile.readAsBytes,
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(
        mockFile.readAsBytesSync,
      ).thenReturn(Uint8List.fromList([1, 2, 3]));
      when(mockFile.lengthSync).thenReturn(3);
      when(mockFile.openRead).thenAnswer(
        (_) => Stream.value(Uint8List.fromList([1, 2, 3])),
      );
      return mockFile;
    }

    group('_addProofModeHeaders', () {
      test(
        'includes X-ProofMode-Manifest header with base64-encoded manifest',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': _pgpSignatureString,
            'deviceAttestation': _deviceAttestationString,
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          expect(capturedOptions, isNotNull);
          final headers = capturedOptions!.headers!;
          expect(headers, contains('X-ProofMode-Manifest'));

          final decoded = utf8.decode(
            base64.decode(headers['X-ProofMode-Manifest'] as String),
          );
          expect(decoded, equals(manifest));
        },
      );

      test(
        'encodes String pgpSignature as base64 without double-encoding',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': _pgpSignatureString,
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final headers = capturedOptions!.headers!;
          expect(headers, contains('X-ProofMode-Signature'));

          final decoded = utf8.decode(
            base64.decode(headers['X-ProofMode-Signature'] as String),
          );
          expect(decoded, equals(_pgpSignatureString));
        },
      );

      test(
        'encodes String deviceAttestation as base64 without double-encoding',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'deviceAttestation': _deviceAttestationString,
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final headers = capturedOptions!.headers!;
          expect(headers, contains('X-ProofMode-Attestation'));

          final decoded = utf8.decode(
            base64.decode(headers['X-ProofMode-Attestation'] as String),
          );
          expect(decoded, equals(_deviceAttestationString));
        },
      );

      test('encodes Map values as JSON then base64', () async {
        arrangeUploadMocks();
        final mockFile = createMockFile();

        final c2paMap = {'id': 'c2pa-123', 'alg': 'sha256'};
        final manifest = jsonEncode({
          'videoHash': 'abc123',
          'c2pa_manifest_id': c2paMap,
        });

        await service.uploadVideo(
          description: 'test',
          videoFile: mockFile,
          nostrPubkey: _testPubkey,
          title: 'test',
          hashtags: const [],
          proofManifestJson: manifest,
        );

        final headers = capturedOptions!.headers!;
        expect(headers, contains('X-ProofMode-C2PA'));

        final decoded = utf8.decode(
          base64.decode(headers['X-ProofMode-C2PA'] as String),
        );
        final decodedMap = jsonDecode(decoded) as Map<String, dynamic>;
        expect(decodedMap['id'], equals('c2pa-123'));
        expect(decodedMap['alg'], equals('sha256'));
      });

      test(
        'encodes c2paManifestId from NativeProofData JSON shape',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          // Inline the NativeProofData JSON shape since models package
          // is not a dependency of blossom_upload_service.
          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'c2paManifestId': 'c2pa-test-id',
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final headers = capturedOptions!.headers!;
          expect(headers, contains('X-ProofMode-C2PA'));

          final decoded = utf8.decode(
            base64.decode(headers['X-ProofMode-C2PA'] as String),
          );
          expect(decoded, equals('c2pa-test-id'));
        },
      );

      test('omits signature header when pgpSignature is null', () async {
        arrangeUploadMocks();
        final mockFile = createMockFile();

        final manifest = jsonEncode({
          'videoHash': 'abc123',
          'deviceAttestation': _deviceAttestationString,
        });

        await service.uploadVideo(
          description: 'test',
          videoFile: mockFile,
          nostrPubkey: _testPubkey,
          title: 'test',
          hashtags: const [],
          proofManifestJson: manifest,
        );

        final headers = capturedOptions!.headers!;
        expect(headers, isNot(contains('X-ProofMode-Signature')));
        expect(headers, contains('X-ProofMode-Attestation'));
      });

      test('omits attestation header when deviceAttestation is null', () async {
        arrangeUploadMocks();
        final mockFile = createMockFile();

        final manifest = jsonEncode({
          'videoHash': 'abc123',
          'pgpSignature': _pgpSignatureString,
        });

        await service.uploadVideo(
          description: 'test',
          videoFile: mockFile,
          nostrPubkey: _testPubkey,
          title: 'test',
          hashtags: const [],
          proofManifestJson: manifest,
        );

        final headers = capturedOptions!.headers!;
        expect(headers, contains('X-ProofMode-Signature'));
        expect(headers, isNot(contains('X-ProofMode-Attestation')));
      });

      test('does not add ProofMode headers when manifest is null', () async {
        arrangeUploadMocks();
        final mockFile = createMockFile();

        await service.uploadVideo(
          description: 'test',
          videoFile: mockFile,
          nostrPubkey: _testPubkey,
          title: 'test',
          hashtags: const [],
          proofManifestJson: null,
        );

        final headers = capturedOptions!.headers!;
        expect(headers, isNot(contains('X-ProofMode-Manifest')));
        expect(headers, isNot(contains('X-ProofMode-Signature')));
        expect(headers, isNot(contains('X-ProofMode-Attestation')));
      });

      test(
        'does not fail upload when manifest JSON is malformed',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: '{invalid-json',
          );

          // Upload should still succeed — ProofMode failure is non-fatal
          verify(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).called(1);
        },
      );

      test(
        'all three headers present for complete manifest',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': _pgpSignatureString,
            'deviceAttestation': _deviceAttestationString,
            'c2pa_manifest_id': 'c2pa-test-id',
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final headers = capturedOptions!.headers!;
          expect(headers, contains('X-ProofMode-Manifest'));
          expect(headers, contains('X-ProofMode-Signature'));
          expect(headers, contains('X-ProofMode-Attestation'));
          expect(headers, contains('X-ProofMode-C2PA'));
        },
      );

      test(
        'drops the bulk headers when an Android attestation busts the budget',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          // Field sizes taken from a real Android capture: an 821-byte PGP
          // signature and a ~54 KB hardware attestation chain. The attestation
          // used to ship twice (base64 in the manifest and again in its own
          // header) for ~147 KB combined, past the 128 KiB that
          // media.divine.video accepts over HTTP/1.1 before answering 502.
          final realWorldSignature = 'S' * 821;
          final realWorldPublicKey = 'K' * 2048;
          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': realWorldSignature,
            'publicKey': realWorldPublicKey,
            'deviceAttestation': 'A' * 53826,
            'c2pa_manifest_id': 'urn:c2pa:7ae319b2-8641-4eea-8203-a1faf72e31e4',
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final headers = capturedOptions!.headers!;
          // The identifying headers survive...
          expect(headers, contains('X-ProofMode-C2PA'));
          expect(headers, contains('X-ProofMode-Signature'));
          expect(headers, contains('X-ProofMode-PublicKey'));
          // ...the two that blow the budget do not.
          expect(headers, isNot(contains('X-ProofMode-Attestation')));
          expect(headers, isNot(contains('X-ProofMode-Manifest')));

          // The signature and the key that verifies it both survive the budget
          // intact, not merely present: truncating either one leaves a proof
          // that cannot be checked from headers alone.
          expect(
            utf8.decode(
              base64.decode(headers['X-ProofMode-Signature'] as String),
            ),
            equals(realWorldSignature),
          );
          expect(
            utf8.decode(
              base64.decode(headers['X-ProofMode-PublicKey'] as String),
            ),
            equals(realWorldPublicKey),
          );
        },
      );

      test(
        'logs over-budget ProofMode header trimming at info severity',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': 'S' * 821,
            'publicKey': 'K' * 2048,
            'deviceAttestation': 'A' * 53826,
            'c2pa_manifest_id': 'urn:c2pa:7ae319b2-8641-4eea-8203-a1faf72e31e4',
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final trimLogs = LogCaptureService().getRecentLogs().where(
            (log) =>
                log.name == 'BlossomUploadService' &&
                log.message.startsWith('ProofMode headers trimmed'),
          );

          expect(trimLogs, hasLength(1));
          expect(trimLogs.single.level, LogLevel.info);
          expect(
            trimLogs.single.message,
            contains('omitted X-ProofMode-Attestation'),
          );
          expect(trimLogs.single.message, contains('X-ProofMode-Manifest'));

          final warnings = LogCaptureService().getRecentLogs(
            minLevel: LogLevel.warning,
          );
          expect(
            warnings.where(
              (log) =>
                  log.name == 'BlossomUploadService' &&
                  log.message.contains('ProofMode headers'),
            ),
            isEmpty,
          );
        },
      );

      test(
        'omits the public key header when the manifest has no publicKey',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': _pgpSignatureString,
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final headers = capturedOptions!.headers!;
          expect(headers, contains('X-ProofMode-Signature'));
          expect(headers, isNot(contains('X-ProofMode-PublicKey')));
        },
      );

      test(
        'keeps every proof header inside the wire budget',
        () async {
          arrangeUploadMocks();
          final mockFile = createMockFile();

          final manifest = jsonEncode({
            'videoHash': 'abc123',
            'pgpSignature': _pgpSignatureString,
            'deviceAttestation': 'A' * 54000,
            'c2pa_manifest_id': 'c2pa-test-id',
          });

          await service.uploadVideo(
            description: 'test',
            videoFile: mockFile,
            nostrPubkey: _testPubkey,
            title: 'test',
            hashtags: const [],
            proofManifestJson: manifest,
          );

          final proofBytes = capturedOptions!.headers!.entries
              .where((e) => e.key.startsWith('X-ProofMode-'))
              .fold<int>(
                0,
                (sum, e) => sum + e.key.length + '${e.value}'.length + 4,
              );

          expect(
            proofBytes,
            lessThanOrEqualTo(BlossomUploadService.maxProofModeHeaderBytes),
          );
        },
      );
    });
  });
}
