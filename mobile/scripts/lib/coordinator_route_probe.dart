// ABOUTME: Probes the account-deletion coordinator route for configured environments.
// ABOUTME: Blocks releases unless selected routes return HTTP 401 (#8125).

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:http/http.dart' as http;

const coordinatorCurrentPath = '/api/account-deletion/attempts/current';
const defaultProbeTimeout = Duration(seconds: 10);
const defaultRetryDelay = Duration(seconds: 2);

typedef StatusFetcher = Future<int> Function(Uri uri, Duration timeout);
typedef RetryWaiter = Future<void> Function(Duration duration);
typedef ConfigReader = String Function();
typedef LineWriter = void Function(String line);

final class CoordinatorTarget {
  const CoordinatorTarget({
    required this.environment,
    required this.apiBaseUrl,
  });

  final String environment;
  final String apiBaseUrl;

  Uri get probeUri => Uri.parse('$apiBaseUrl$coordinatorCurrentPath');
}

enum ProbeState { serving, missing, unavailable, unexpected, unreachable }

final class ProbeResult {
  const ProbeResult({
    required this.target,
    required this.state,
    this.statusCode,
    this.error,
    this.attempts = 1,
  });

  final CoordinatorTarget target;
  final ProbeState state;
  final int? statusCode;
  final Object? error;
  final int attempts;

  bool get passed => state == ProbeState.serving;

  String get message => switch (state) {
    ProbeState.serving =>
      'PASS ${target.environment}: ${target.probeUri} returned $statusCode'
          '${_attemptSuffix(attempts)}.',
    ProbeState.missing =>
      'FAIL ${target.environment}: coordinator route is not serving at '
          '${target.probeUri} (HTTP 404).',
    ProbeState.unavailable =>
      'FAIL ${target.environment}: coordinator route is unavailable at '
          '${target.probeUri} (HTTP $statusCode${_attemptSuffix(attempts)}).',
    ProbeState.unexpected =>
      'FAIL ${target.environment}: coordinator route returned an unexpected '
          'response at ${target.probeUri} (HTTP $statusCode).',
    ProbeState.unreachable =>
      'FAIL ${target.environment}: coordinator route is unreachable at '
          '${target.probeUri} (${_safeError(error)}'
          '${_attemptSuffix(attempts)}).',
  };
}

String _attemptSuffix(int attempts) =>
    attempts > 1 ? ' after $attempts attempts' : '';

String _safeError(Object? error) {
  if (error is TimeoutException) return 'request timed out';
  if (error is SocketException) return 'network connection failed';
  if (error is HandshakeException) return 'TLS handshake failed';
  if (error is http.ClientException) return 'HTTP client failed';
  return 'request failed';
}

/// Extracts all non-local API targets from `environment_config.dart`.
///
/// The extractor deliberately validates the current `apiBaseUrl` derivation
/// rather than carrying a second host list. A new enum value or a changed URL
/// rule fails extraction until this check understands the new configuration.
List<CoordinatorTarget> extractCoordinatorTargets(String source) {
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  if (parsed.errors.any(
    (error) => error.diagnosticCode.severity == DiagnosticSeverity.ERROR,
  )) {
    throw const FormatException('environment_config.dart does not parse');
  }

  final enumDeclaration = parsed.unit.declarations
      .whereType<EnumDeclaration>()
      .where(
        (declaration) =>
            declaration.namePart.typeName.lexeme == 'AppEnvironment',
      )
      .singleOrNull;
  if (enumDeclaration == null) {
    throw const FormatException('AppEnvironment enum was not found');
  }

  final environments = enumDeclaration.body.constants
      .map((constant) => constant.name.lexeme)
      .where((name) => name != 'local')
      .toList(growable: false);
  if (!enumDeclaration.body.constants.any(
    (constant) => constant.name.lexeme == 'local',
  )) {
    throw const FormatException('AppEnvironment.local was not found');
  }

  final environmentClass = parsed.unit.declarations
      .whereType<ClassDeclaration>()
      .where(
        (declaration) =>
            declaration.namePart.typeName.lexeme == 'EnvironmentConfig',
      )
      .singleOrNull;
  if (environmentClass == null) {
    throw const FormatException('EnvironmentConfig class was not found');
  }

  String getterSource(String name) {
    final getter = environmentClass.body.members
        .whereType<MethodDeclaration>()
        .where((member) => member.isGetter && member.name.lexeme == name)
        .singleOrNull;
    if (getter == null) {
      throw FormatException('EnvironmentConfig.$name was not found');
    }
    return getter.toSource();
  }

  final apiSource = getterSource('apiBaseUrl');
  const requiredApiFragments = [
    'environment == AppEnvironment.production',
    'return productionApiBaseUrl',
    'final url = relayUrl',
    "url.replaceFirst('wss://', 'https://')",
    "url.replaceFirst('ws://', 'http://')",
  ];
  for (final fragment in requiredApiFragments) {
    if (!apiSource.contains(fragment)) {
      throw FormatException(
        'Unsupported apiBaseUrl configuration: missing $fragment',
      );
    }
  }

  final productionUrl = _topLevelStringConstant(
    parsed.unit,
    'productionApiBaseUrl',
  );
  final relaySource = getterSource('relayUrl');
  final relayPattern = RegExp(
    r"case AppEnvironment\.(\w+):\s*return '([^'$]+)';",
  );
  final relayUrls = <String, String>{
    for (final match in relayPattern.allMatches(relaySource))
      match.group(1)!: match.group(2)!,
  };

  return environments
      .map((environment) {
        if (environment == 'production') {
          return CoordinatorTarget(
            environment: environment.toUpperCase(),
            apiBaseUrl: productionUrl,
          );
        }
        final relayUrl = relayUrls[environment];
        if (relayUrl == null || !relayUrl.startsWith('wss://')) {
          throw FormatException(
            'Cannot resolve apiBaseUrl for AppEnvironment.$environment',
          );
        }
        return CoordinatorTarget(
          environment: environment.toUpperCase(),
          apiBaseUrl: relayUrl.replaceFirst('wss://', 'https://'),
        );
      })
      .toList(growable: false);
}

String _topLevelStringConstant(CompilationUnit unit, String name) {
  for (final declaration
      in unit.declarations.whereType<TopLevelVariableDeclaration>()) {
    for (final variable in declaration.variables.variables) {
      if (variable.name.lexeme != name) continue;
      final initializer = variable.initializer;
      if (initializer is SimpleStringLiteral) return initializer.value;
      throw FormatException('$name is not a string literal');
    }
  }
  throw FormatException('$name was not found');
}

Future<ProbeResult> probeCoordinatorRoute(
  CoordinatorTarget target, {
  required StatusFetcher fetchStatus,
  RetryWaiter waitBeforeRetry = _waitWithTimer,
  Duration timeout = defaultProbeTimeout,
  Duration retryDelay = defaultRetryDelay,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < 2; attempt++) {
    if (attempt > 0) await waitBeforeRetry(retryDelay);
    try {
      final statusCode = await fetchStatus(target.probeUri, timeout);
      final attempts = attempt + 1;
      if (statusCode == HttpStatus.unauthorized) {
        return ProbeResult(
          target: target,
          state: ProbeState.serving,
          statusCode: statusCode,
          attempts: attempts,
        );
      }
      if (statusCode == HttpStatus.notFound) {
        return ProbeResult(
          target: target,
          state: ProbeState.missing,
          statusCode: statusCode,
          attempts: attempts,
        );
      }
      if (statusCode >= HttpStatus.internalServerError && statusCode < 600) {
        if (attempt == 0) continue;
        return ProbeResult(
          target: target,
          state: ProbeState.unavailable,
          statusCode: statusCode,
          attempts: attempts,
        );
      }
      return ProbeResult(
        target: target,
        state: ProbeState.unexpected,
        statusCode: statusCode,
        attempts: attempts,
      );
    } on Object catch (error) {
      if (!_isRetryableNetworkError(error)) rethrow;
      lastError = error;
    }
  }
  return ProbeResult(
    target: target,
    state: ProbeState.unreachable,
    error: lastError,
    attempts: 2,
  );
}

bool _isRetryableNetworkError(Object error) =>
    error is TimeoutException ||
    error is SocketException ||
    error is HandshakeException ||
    error is http.ClientException;

Future<void> _waitWithTimer(Duration duration) {
  final completer = Completer<void>();
  Timer(duration, completer.complete);
  return completer.future;
}

Future<int> fetchCoordinatorStatus(
  Uri uri,
  Duration timeout, {
  http.Client? client,
}) async {
  final requestClient = client ?? http.Client();
  try {
    final request = http.Request('GET', uri)..followRedirects = false;
    return (await requestClient.send(request).timeout(timeout)).statusCode;
  } finally {
    if (client == null) requestClient.close();
  }
}

Future<int> runCoordinatorRouteProbe(
  List<String> arguments, {
  required ConfigReader readEnvironmentConfig,
  required StatusFetcher fetchStatus,
  RetryWaiter waitBeforeRetry = _waitWithTimer,
  LineWriter writeStdout = print,
  LineWriter writeStderr = _writeStderr,
}) async {
  String? selectedEnvironment;
  for (final argument in arguments) {
    if (argument.startsWith('--environment=')) {
      if (selectedEnvironment != null) {
        writeStderr('The --environment argument may only be provided once.');
        writeStderr(_usage);
        return 64;
      }
      selectedEnvironment = argument
          .substring('--environment='.length)
          .toUpperCase();
      if (selectedEnvironment.isEmpty) {
        writeStderr('The --environment value must not be empty.');
        writeStderr(_usage);
        return 64;
      }
    } else {
      writeStderr('Unknown argument: $argument');
      writeStderr(_usage);
      return 64;
    }
  }

  try {
    final source = readEnvironmentConfig();
    var targets = extractCoordinatorTargets(source);
    if (selectedEnvironment != null) {
      targets = targets
          .where((target) => target.environment == selectedEnvironment)
          .toList(growable: false);
      if (targets.isEmpty) {
        writeStderr(
          'Environment $selectedEnvironment is not a configured non-local '
          'environment.',
        );
        writeStderr(_usage);
        return 64;
      }
    }

    var failed = false;
    for (final target in targets) {
      final result = await probeCoordinatorRoute(
        target,
        fetchStatus: fetchStatus,
        waitBeforeRetry: waitBeforeRetry,
      );
      (result.passed ? writeStdout : writeStderr)(result.message);
      failed |= !result.passed;
    }
    return failed ? 1 : 0;
  } on Object catch (error) {
    writeStderr('FAIL coordinator route configuration: $error');
    return 1;
  }
}

const _usage =
    'Usage: dart run scripts/lib/coordinator_route_probe.dart '
    '[--environment=NAME]';

void _writeStderr(String line) => stderr.writeln(line);

Future<void> main(List<String> arguments) async {
  exitCode = await runCoordinatorRouteProbe(
    arguments,
    readEnvironmentConfig: () =>
        File('lib/models/environment_config.dart').readAsStringSync(),
    fetchStatus: fetchCoordinatorStatus,
  );
}

extension<T> on Iterable<T> {
  T? get singleOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    final value = iterator.current;
    if (iterator.moveNext()) return null;
    return value;
  }
}
