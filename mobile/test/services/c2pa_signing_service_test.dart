// ABOUTME: Tests C2PA signing failure handling and derived-file re-signing
// ABOUTME: Covers typed failures, manifest gates, and parent ingredients

import 'dart:io';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockC2pa extends Mock implements C2pa {}

class _MockManifestBuilder extends Mock implements ManifestBuilder {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const IngredientConfig());
    registerFallbackValue(const ActionConfig(action: 'c2pa.edited'));
    registerFallbackValue(RemoteSigner(configurationUrl: ''));
  });

  group(C2paSigningService, () {
    late _MockC2pa mockC2pa;
    late C2paSigningService service;
    late Directory tempDir;

    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Divine',
        packageName: 'app.divine',
        version: '1.2.3',
        buildNumber: '10',
        buildSignature: '',
      );
      mockC2pa = _MockC2pa();
      service = C2paSigningService(c2pa: mockC2pa);
      tempDir = Directory.systemTemp.createTempSync('c2pa_resign_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writeFile(String name, List<int> bytes) {
      final file = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
      return file;
    }

    group('failure classification', () {
      test('classifies iOS secure connection failures as TLS errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'C2PA_ERROR',
            message: 'A TLS error caused the secure connection to fail.',
          ),
        );

        expect(reason, C2paSigningFailureReason.tls);
      });

      test('classifies connection failures as network errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'C2PA_ERROR',
            message: 'Connection reset by peer',
          ),
        );

        expect(reason, C2paSigningFailureReason.network);
      });

      test('classifies cannot-connect failures as network errors', () {
        final reason = C2paSigningService.classifyFailureReason(
          PlatformException(
            code: 'C2PA_ERROR',
            message: 'Could not connect to the server.',
          ),
        );

        expect(reason, C2paSigningFailureReason.network);
      });

      test('returns typed failure reason when remote signing throws', () async {
        final video = writeFile('video.mp4', const [0, 1, 2, 3]);
        final failingService = C2paSigningService(
          c2pa: _FailingC2pa(
            PlatformException(
              code: 'C2PA_ERROR',
              message: 'A TLS error caused the secure connection to fail.',
            ),
          ),
        );

        final result = await failingService.signVideo(videoPath: video.path);

        expect(result.success, isFalse);
        expect(result.signedFilePath, video.path);
        expect(result.failureReason, C2paSigningFailureReason.tls);
        expect(result.error, contains('A TLS error caused'));
      });
    });

    group('resignDerived', () {
      test(
        'skips re-signing and leaves the file untouched when the source '
        'carries no manifest',
        () async {
          when(
            () => mockC2pa.readManifestFromFile(any()),
          ).thenAnswer((_) async => const ManifestStoreInfo());

          final output = writeFile('out.mp4', const [1, 2, 3]);
          final source = writeFile('src.mp4', const [4, 5, 6]);

          final result = await service.resignDerived(
            outputPath: output.path,
            sourcePath: source.path,
            action: C2paEditActions.edited,
          );

          expect(result.success, isFalse);
          verifyNever(() => mockC2pa.createBuilder(any()));
          expect(output.readAsBytesSync(), equals([1, 2, 3]));
        },
      );

      test(
        'carries the source manifest forward: parentOf ingredient, edit '
        'action, and writes the signed bytes back in place',
        () async {
          when(() => mockC2pa.readManifestFromFile(any())).thenAnswer(
            (_) async => const ManifestStoreInfo(activeManifest: 'urn:c2pa:x'),
          );

          final builder = _MockManifestBuilder();
          when(
            () => mockC2pa.createBuilder(any()),
          ).thenAnswer((_) async => builder);
          when(
            () => builder.addIngredient(
              data: any(named: 'data'),
              mimeType: any(named: 'mimeType'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async {});
          final signedBytes = Uint8List.fromList(const [9, 9, 9, 9, 9]);
          when(
            () => builder.sign(
              sourceData: any(named: 'sourceData'),
              mimeType: any(named: 'mimeType'),
              signer: any(named: 'signer'),
            ),
          ).thenAnswer(
            (_) async =>
                BuilderSignResult(signedData: signedBytes, manifestSize: 5),
          );

          final output = writeFile('out.mp4', const [1, 2, 3]);
          final source = writeFile('src.mp4', const [4, 5, 6]);

          final result = await service.resignDerived(
            outputPath: output.path,
            sourcePath: source.path,
            action: C2paEditActions.edited,
          );

          expect(result.success, isTrue);

          final ingredientConfig =
              verify(
                    () => builder.addIngredient(
                      data: any(named: 'data'),
                      mimeType: any(named: 'mimeType'),
                      config: captureAny(named: 'config'),
                    ),
                  ).captured.single
                  as IngredientConfig;
          expect(ingredientConfig.relationship, Relationship.parentOf);

          final recordedAction =
              verify(() => builder.addAction(captureAny())).captured.single
                  as ActionConfig;
          // Literal token: pins the protocol surface, not just the constant.
          expect(recordedAction.action, 'c2pa.edited');

          verify(() => builder.setIntent(ManifestIntent.edit)).called(1);
          verify(builder.dispose).called(1);
          expect(output.readAsBytesSync(), equals(signedBytes));
        },
      );

      test(
        'returns failure without signing when the output does not exist',
        () async {
          final result = await service.resignDerived(
            outputPath: '${tempDir.path}/missing.mp4',
            sourcePath: '${tempDir.path}/also-missing.mp4',
            action: C2paEditActions.edited,
          );

          expect(result.success, isFalse);
          verifyNever(() => mockC2pa.readManifestFromFile(any()));
          verifyNever(() => mockC2pa.createBuilder(any()));
        },
      );
    });
  });
}

class _FailingC2pa extends C2pa {
  _FailingC2pa(this.error);

  final Object error;

  @override
  Future<void> signFile({
    required String sourcePath,
    required String destPath,
    required String manifestJson,
    required C2paSigner signer,
  }) async {
    throw error;
  }
}
