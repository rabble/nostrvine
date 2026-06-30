import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const proofModeChannel = MethodChannel('org.openvine/proofmode');
  const proofHash =
      'bfe97053586981c5d2373625c3ee921d8af88c79fca442e189a82230d99bdc78';

  setUp(() async {
    await LogCaptureService().clearAllLogs();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(proofModeChannel, null);
    await LogCaptureService().clearAllLogs();
  });

  group('readProofMetadata logging', () {
    test(
      'logs missing proof directory as debug for expected pre-generation read',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(proofModeChannel, (call) async {
              expect(call.method, 'getProofDir');
              expect(call.arguments, {'proofHash': proofHash});
              return null;
            });

        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
          warnIfMissing: false,
        );

        expect(metadata, isNull);
        expect(
          _logsContaining(
            'No proof directory found for hash',
          ).where((log) => log.level == LogLevel.warning),
          isEmpty,
        );
        expect(
          _latestLogContaining('No proof directory found for hash')?.level,
          LogLevel.debug,
        );
      },
    );

    test(
      'logs missing proof directory as warning for unexpected post-generation read',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(proofModeChannel, (call) async {
              expect(call.method, 'getProofDir');
              expect(call.arguments, {'proofHash': proofHash});
              return null;
            });

        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
        );

        expect(metadata, isNull);
        expect(
          _latestLogContaining('No proof directory found for hash')?.level,
          LogLevel.warning,
        );
      },
    );

    test(
      'logs nonexistent proof directory as debug when missing proof is expected',
      () async {
        final missingProofDir =
            '${Directory.systemTemp.path}/missing-proofmode-$proofHash';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(proofModeChannel, (call) async {
              expect(call.method, 'getProofDir');
              expect(call.arguments, {'proofHash': proofHash});
              return missingProofDir;
            });

        final metadata = await NativeProofModeService.readProofMetadata(
          proofHash,
          warnIfMissing: false,
        );

        expect(metadata, isNull);
        expect(
          _logsContaining(
            'Proof directory does not exist',
          ).where((log) => log.level == LogLevel.warning),
          isEmpty,
        );
        expect(
          _latestLogContaining('Proof directory does not exist')?.level,
          LogLevel.debug,
        );
      },
    );
  });
}

Iterable<LogEntry> _logsContaining(String message) {
  return LogCaptureService().getRecentLogs().where(
    (log) => log.message.contains(message),
  );
}

LogEntry? _latestLogContaining(String message) {
  final matches = _logsContaining(message);
  return matches.isEmpty ? null : matches.last;
}
