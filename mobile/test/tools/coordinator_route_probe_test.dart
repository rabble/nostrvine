// ABOUTME: Tests config extraction and coordinator route response classification.
// ABOUTME: Keeps release checks exhaustive, credential-free, and diagnostic (#8125).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/coordinator_route_probe.dart';

const currentConfigFixture = r'''
const productionApiBaseUrl = 'https://api.divine.video';
enum AppEnvironment { poc, staging, test, production, local }
class EnvironmentConfig {
  String get relayUrl {
    switch (environment) {
      case AppEnvironment.poc: return 'wss://relay.poc.dvines.org';
      case AppEnvironment.staging: return 'wss://relay.staging.divine.video';
      case AppEnvironment.test: return 'wss://relay.test.dvines.org';
      case AppEnvironment.local: return 'ws://$localHost:47777';
      case AppEnvironment.production: return 'wss://relay.divine.video';
    }
  }
  String get apiBaseUrl {
    if (environment == AppEnvironment.local) return 'http://$localHost:47777';
    if (environment == AppEnvironment.production) return productionApiBaseUrl;
    final url = relayUrl;
    if (url.startsWith('wss://')) return url.replaceFirst('wss://', 'https://');
    if (url.startsWith('ws://')) return url.replaceFirst('ws://', 'http://');
    return url;
  }
}
''';

void main() {
  group('extractCoordinatorTargets', () {
    test('extracts the repository environment config', () {
      final targets = extractCoordinatorTargets(
        File('lib/models/environment_config.dart').readAsStringSync(),
      );

      expect(
        targets.map((target) => target.environment),
        ['POC', 'STAGING', 'TEST', 'PRODUCTION'],
      );
    });

    test('derives every non-local target from environment config', () {
      final targets = extractCoordinatorTargets(currentConfigFixture);

      expect(
        targets.map((target) => '${target.environment}:${target.apiBaseUrl}'),
        [
          'POC:https://relay.poc.dvines.org',
          'STAGING:https://relay.staging.divine.video',
          'TEST:https://relay.test.dvines.org',
          'PRODUCTION:https://api.divine.video',
        ],
      );
    });

    test('fails when a new environment cannot be resolved', () {
      final changed = currentConfigFixture.replaceFirst(
        'poc, staging',
        'poc, preview, staging',
      );

      expect(
        () => extractCoordinatorTargets(changed),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('AppEnvironment.preview'),
          ),
        ),
      );
    });
  });

  group('probeCoordinatorRoute', () {
    const target = CoordinatorTarget(
      environment: 'STAGING',
      apiBaseUrl: 'https://relay.staging.divine.video',
    );
    Future<void> noWait(Duration _) async {}

    test(
      'passes a mounted route that rejects unauthenticated access',
      () async {
        final result = await probeCoordinatorRoute(
          target,
          fetchStatus: (_, _) async => HttpStatus.unauthorized,
          waitBeforeRetry: noWait,
        );

        expect(result.state, ProbeState.serving);
        expect(result.message, contains('returned 401'));
      },
    );

    test('fails a 404 with the environment and exact URL', () async {
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async => HttpStatus.notFound,
        waitBeforeRetry: noWait,
      );

      expect(result.state, ProbeState.missing);
      expect(result.message, contains('STAGING'));
      expect(
        result.message,
        contains('https://relay.staging.divine.video$coordinatorCurrentPath'),
      );
    });

    test('retries once then reports unreachable distinctly', () async {
      var attempts = 0;
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async {
          attempts++;
          throw const SocketException('synthetic private detail');
        },
        waitBeforeRetry: noWait,
      );

      expect(attempts, 2);
      expect(result.state, ProbeState.unreachable);
      expect(result.message, contains('STAGING'));
      expect(result.message, contains('unreachable'));
      expect(result.message, isNot(contains('synthetic private detail')));
      expect(result.message, isNot(contains('authorization')));
      expect(result.message, isNot(contains('token')));
    });

    test('classifies a timeout without exposing its details', () async {
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: (_, _) async => throw TimeoutException('secret=value'),
        waitBeforeRetry: noWait,
      );

      expect(result.message, contains('request timed out'));
      expect(result.message, isNot(contains('secret=value')));
    });
  });
}
