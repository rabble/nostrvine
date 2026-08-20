// ABOUTME: Verifies the vendored product analytics contract against its explicit lock.
// ABOUTME: Fails CI when the generated Dart artifact or embedded source commit drifts.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

void main() {
  final lockFile = File('../analytics-contract.lock');
  final lock = jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>;
  const expectedArtifact = 'mobile/lib/generated/product_analytics.dart';

  if (lock['artifact'] != expectedArtifact) {
    fail('analytics contract lock must target $expectedArtifact');
  }

  final artifact = File('lib/generated/product_analytics.dart');
  final bytes = artifact.readAsBytesSync();
  final actualSha = sha256.convert(bytes).toString();
  if (actualSha != lock['artifact_sha256']) {
    fail(
      'analytics contract artifact checksum drifted: '
      'expected ${lock['artifact_sha256']}, got $actualSha',
    );
  }

  final contents = utf8.decode(bytes);
  final embeddedCommit = RegExp(
    'Source contract commit: ([0-9a-f]{40})',
  ).firstMatch(contents)?.group(1);
  if (embeddedCommit != lock['contract_commit']) {
    fail('analytics contract artifact commit does not match the lock');
  }
  if (!contents.contains('DO NOT EDIT')) {
    fail('analytics contract artifact is missing its generated-file header');
  }

  stdout.writeln(
    'analytics contract pin verified at ${lock['contract_commit']}',
  );
}
