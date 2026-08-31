// ABOUTME: Verifies the vendored product analytics artifact is self-consistent with
// ABOUTME: the lock and manifest (hashes, schema, source paths, pinned upstream commits).
// ABOUTME: Fails CI when any of them drift. Purely local: it checks the recorded
// ABOUTME: provenance, never contacts the upstream repo.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _expectedArtifact = 'mobile/lib/generated/product_analytics.dart';
const _expectedManifest = 'analytics-contract.manifest.json';
const _expectedSourceArtifact = 'analytics/generated/product_analytics.dart';
const _expectedSourceManifest = 'analytics/generated/manifest.json';
const _expectedLockKeys = {
  'artifact',
  'artifact_commit',
  'artifact_sha256',
  'contract_commit',
  'manifest',
  'manifest_sha256',
  'schema_version',
  'source_artifact',
  'source_manifest',
};

class ContractCheckException implements Exception {
  const ContractCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

Directory repositoryRootForScript(Uri scriptUri) {
  final script = File.fromUri(scriptUri);
  return script.parent.parent.parent;
}

void checkProductAnalyticsContract(Directory repositoryRoot) {
  final lock = _readJsonObject(
    _file(repositoryRoot, 'analytics-contract.lock'),
    'analytics contract lock',
  );
  if (lock.keys.toSet().difference(_expectedLockKeys).isNotEmpty ||
      _expectedLockKeys.difference(lock.keys.toSet()).isNotEmpty) {
    throw const ContractCheckException(
      'analytics contract lock fields do not match the required provenance fields',
    );
  }

  _requireEqual(lock, 'artifact', _expectedArtifact);
  _requireEqual(lock, 'manifest', _expectedManifest);
  _requireEqual(lock, 'source_artifact', _expectedSourceArtifact);
  _requireEqual(lock, 'source_manifest', _expectedSourceManifest);

  final contractCommit = _requireCommit(lock, 'contract_commit');
  _requireCommit(lock, 'artifact_commit');
  final schemaVersion = _requireInt(lock, 'schema_version');
  if (schemaVersion != 2) {
    throw ContractCheckException(
      'analytics contract schema version must be 2, got $schemaVersion',
    );
  }

  final manifestFile = _file(repositoryRoot, _expectedManifest);
  final manifestBytes = _readBytes(manifestFile, 'analytics contract manifest');
  _requireSha(
    actual: sha256.convert(manifestBytes).toString(),
    expected: _requireString(lock, 'manifest_sha256'),
    label: 'manifest checksum',
  );
  final manifest = _decodeJsonObject(
    manifestBytes,
    'analytics contract manifest',
  );
  if (manifest['contract_commit'] != contractCommit) {
    throw const ContractCheckException(
      'analytics contract manifest commit does not match the lock',
    );
  }
  if (manifest['schema_version'] != schemaVersion) {
    throw const ContractCheckException(
      'analytics contract schema version does not match the manifest',
    );
  }
  if (manifest['event_id_algorithm'] != 'sha256-rfc8785-v1') {
    throw const ContractCheckException(
      'analytics contract manifest event ID algorithm must be sha256-rfc8785-v1',
    );
  }

  final artifacts = manifest['artifacts'];
  if (artifacts is! Map<String, dynamic>) {
    throw const ContractCheckException(
      'analytics contract manifest artifacts must be an object',
    );
  }
  final sourceName = _expectedSourceArtifact.split('/').last;
  final sourceEntry = artifacts[sourceName];
  if (sourceEntry is! Map<String, dynamic> ||
      sourceEntry['path'] != lock['source_artifact']) {
    throw const ContractCheckException(
      'analytics contract source artifact is not identified by the manifest',
    );
  }
  if (sourceEntry['sha256'] != lock['artifact_sha256']) {
    throw const ContractCheckException(
      'analytics contract artifact checksum does not match the manifest',
    );
  }

  final artifactBytes = _readBytes(
    _file(repositoryRoot, _expectedArtifact),
    'analytics contract artifact',
  );
  _requireSha(
    actual: sha256.convert(artifactBytes).toString(),
    expected: _requireString(lock, 'artifact_sha256'),
    label: 'artifact checksum',
  );
  final contents = utf8.decode(artifactBytes);
  final embeddedCommit = RegExp(
    'Source contract commit: ([0-9a-f]{40})',
  ).firstMatch(contents)?.group(1);
  if (embeddedCommit != contractCommit) {
    throw const ContractCheckException(
      'analytics contract artifact commit does not match the lock',
    );
  }
  final embeddedSchema = RegExp(
    'productAnalyticsV([0-9]+)SchemaVersion = ([0-9]+);',
  ).firstMatch(contents);
  if (embeddedSchema?.group(1) != '$schemaVersion' ||
      embeddedSchema?.group(2) != '$schemaVersion') {
    throw const ContractCheckException(
      'analytics contract schema version does not match the generated artifact',
    );
  }
  final embeddedEventIdAlgorithm = RegExp(
    "productAnalyticsV2EventIdAlgorithm = '([^']+)';",
  ).firstMatch(contents)?.group(1);
  if (embeddedEventIdAlgorithm != 'sha256-rfc8785-v1') {
    throw const ContractCheckException(
      'analytics contract event ID algorithm does not match the generated artifact',
    );
  }
  if (!contents.contains('DO NOT EDIT')) {
    throw const ContractCheckException(
      'analytics contract artifact is missing its generated-file header',
    );
  }
}

File _file(Directory root, String relativePath) =>
    File.fromUri(root.uri.resolve(relativePath));

List<int> _readBytes(File file, String label) {
  try {
    return file.readAsBytesSync();
  } on FileSystemException catch (error) {
    throw ContractCheckException('$label is unreadable: ${error.message}');
  }
}

Map<String, dynamic> _readJsonObject(File file, String label) =>
    _decodeJsonObject(_readBytes(file, label), label);

Map<String, dynamic> _decodeJsonObject(List<int> bytes, String label) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException catch (error) {
    throw ContractCheckException('$label is invalid JSON: ${error.message}');
  }
  throw ContractCheckException('$label must be a JSON object');
}

String _requireString(Map<String, dynamic> object, String key) {
  final value = object[key];
  if (value is String && value.isNotEmpty) return value;
  throw ContractCheckException(
    'analytics contract lock field $key must be a string',
  );
}

int _requireInt(Map<String, dynamic> object, String key) {
  final value = object[key];
  if (value is int) return value;
  throw ContractCheckException(
    'analytics contract lock field $key must be an integer',
  );
}

String _requireCommit(Map<String, dynamic> object, String key) {
  final value = _requireString(object, key);
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
    throw ContractCheckException(
      'analytics contract lock field $key must be a full Git commit',
    );
  }
  return value;
}

void _requireEqual(
  Map<String, dynamic> object,
  String key,
  String expected,
) {
  if (object[key] != expected) {
    final label = key.replaceAll('_', ' ');
    throw ContractCheckException(
      'analytics contract lock field $label must be $expected',
    );
  }
}

void _requireSha({
  required String actual,
  required String expected,
  required String label,
}) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected) || actual != expected) {
    throw ContractCheckException(
      'analytics contract $label drifted: expected $expected, got $actual',
    );
  }
}

void main() {
  try {
    final repositoryRoot = repositoryRootForScript(Platform.script);
    checkProductAnalyticsContract(repositoryRoot);
    final lock = _readJsonObject(
      _file(repositoryRoot, 'analytics-contract.lock'),
      'analytics contract lock',
    );
    stdout.writeln(
      'analytics contract pin verified at ${lock['contract_commit']} '
      'from artifact ${lock['artifact_commit']}',
    );
  } on ContractCheckException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
