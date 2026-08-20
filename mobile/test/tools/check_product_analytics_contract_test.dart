// ABOUTME: Tests product analytics contract provenance and drift verification.
// ABOUTME: Covers valid pins, tampered artifacts, inert lock fields, and path resolution.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tools/check_product_analytics_contract.dart' as checker;

void main() {
  group('checkProductAnalyticsContract', () {
    late Directory sandbox;
    late File artifact;
    late File lockFile;
    late File manifestFile;
    late Map<String, Object?> lock;
    late Map<String, Object?> manifest;

    const contractCommit = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const artifactCommit = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const artifactPath = 'mobile/lib/generated/product_analytics.dart';
    const sourceArtifact = 'analytics/generated/product_analytics.dart';

    void writeManifestAndLock() {
      final manifestText = '${jsonEncode(manifest)}\n';
      manifestFile.writeAsStringSync(manifestText);
      lock['manifest_sha256'] = sha256
          .convert(utf8.encode(manifestText))
          .toString();
      lockFile.writeAsStringSync('${jsonEncode(lock)}\n');
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('analytics_contract_');
      artifact = File(p.join(sandbox.path, artifactPath))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '// Source contract commit: $contractCommit\n'
          '// DO NOT EDIT.\n'
          'const int productAnalyticsV2SchemaVersion = 2;\n',
        );
      lockFile = File(p.join(sandbox.path, 'analytics-contract.lock'));
      manifestFile = File(
        p.join(sandbox.path, 'analytics-contract.manifest.json'),
      );
      final artifactSha = sha256.convert(artifact.readAsBytesSync()).toString();
      manifest = {
        'artifacts': {
          'product_analytics.dart': {
            'path': sourceArtifact,
            'sha256': artifactSha,
          },
        },
        'contract_commit': contractCommit,
        'schema_version': 2,
      };
      lock = {
        'artifact': artifactPath,
        'artifact_commit': artifactCommit,
        'artifact_sha256': artifactSha,
        'contract_commit': contractCommit,
        'manifest': 'analytics-contract.manifest.json',
        'manifest_sha256': '',
        'schema_version': 2,
        'source_artifact': sourceArtifact,
        'source_manifest': 'analytics/generated/manifest.json',
      };
      writeManifestAndLock();
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('accepts a complete lock derived from the upstream manifest', () {
      expect(
        () => checker.checkProductAnalyticsContract(sandbox),
        returnsNormally,
      );
    });

    test('rejects a modified generated artifact', () {
      artifact.writeAsStringSync('// drift\n', mode: FileMode.append);

      expect(
        () => checker.checkProductAnalyticsContract(sandbox),
        throwsA(
          isA<checker.ContractCheckException>().having(
            (error) => error.message,
            'message',
            contains('artifact checksum'),
          ),
        ),
      );
    });

    test('rejects a source path not present in the upstream manifest', () {
      lock['source_artifact'] = 'analytics/generated/other.dart';
      writeManifestAndLock();

      expect(
        () => checker.checkProductAnalyticsContract(sandbox),
        throwsA(
          isA<checker.ContractCheckException>().having(
            (error) => error.message,
            'message',
            contains('source artifact'),
          ),
        ),
      );
    });

    test('rejects a schema version inconsistent with the manifest', () {
      lock['schema_version'] = 1;
      writeManifestAndLock();

      expect(
        () => checker.checkProductAnalyticsContract(sandbox),
        throwsA(
          isA<checker.ContractCheckException>().having(
            (error) => error.message,
            'message',
            contains('schema version'),
          ),
        ),
      );
    });

    test('rejects an artifact commit that is not a full Git commit', () {
      lock['artifact_commit'] = 'branch-name';
      writeManifestAndLock();

      expect(
        () => checker.checkProductAnalyticsContract(sandbox),
        throwsA(
          isA<checker.ContractCheckException>().having(
            (error) => error.message,
            'message',
            contains('artifact_commit'),
          ),
        ),
      );
    });

    test('rejects unvalidated lock fields', () {
      lock['unused'] = true;
      writeManifestAndLock();

      expect(
        () => checker.checkProductAnalyticsContract(sandbox),
        throwsA(
          isA<checker.ContractCheckException>().having(
            (error) => error.message,
            'message',
            contains('provenance fields'),
          ),
        ),
      );
    });

    test('derives the repository root from the script path, not cwd', () {
      final script = File(
        p.join(sandbox.path, 'mobile', 'tools', 'check_contract.dart'),
      );

      expect(checker.repositoryRootForScript(script.uri).path, sandbox.path);
    });
  });
}
