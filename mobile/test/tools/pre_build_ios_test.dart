// ABOUTME: Tests for mobile/pre_build_ios.sh, the Runner scheme's pre-action.
// ABOUTME: Pins that it syncs CocoaPods without ever invoking Flutter.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `pre_build_ios.sh` against a sandboxed copy of the project layout.
///
/// The shared Runner scheme runs this script as a pre-action of every Xcode
/// build. Any Flutter command it runs there re-injects plugins, which rewrites
/// `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/
/// Package.swift` at Flutter's default `.iOS("13.0")` floor. Nothing on the
/// Xcode-driven build path raises that floor back to the project's 16.0, so
/// the build then fails with "requires minimum platform version 16.0 ... but
/// this target supports 13.0" for every plugin with a higher floor. The
/// script must therefore never invoke `flutter`; that property is pinned here.
void main() {
  group('pre_build_ios.sh', () {
    late Directory sandbox;
    late String scriptPath;
    late Directory stubBin;
    late Directory stubLogs;

    File stubLog(String tool) => File(p.join(stubLogs.path, '$tool.log'));

    /// Installs a `tool` shim on the sandboxed PATH that records its argv.
    void installStub(String tool) {
      final stub = File(p.join(stubBin.path, tool))
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'printf \'%s\\n\' "\$*" >> "\$STUB_LOG_DIR/$tool.log"\n',
        );
      final chmod = Process.runSync('chmod', ['+x', stub.path]);
      expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
    }

    void writeFile(String relativePath, DateTime modified) {
      File(p.join(sandbox.path, relativePath))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('# $relativePath\n')
        ..setLastModifiedSync(modified);
    }

    ProcessResult runScript() {
      return Process.runSync(
        'bash',
        [scriptPath],
        workingDirectory: sandbox.path,
        environment: {
          'PATH': '${stubBin.path}:/usr/bin:/bin',
          'HOME': p.join(sandbox.path, 'home'),
          'STUB_LOG_DIR': stubLogs.path,
        },
        includeParentEnvironment: false,
      );
    }

    void expectSuccess(ProcessResult result) {
      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('pre_build_ios_');
      final realScript = File(
        p.join(Directory.current.path, 'pre_build_ios.sh'),
      );
      expect(
        realScript.existsSync(),
        isTrue,
        reason: 'mobile/pre_build_ios.sh must exist',
      );
      scriptPath = p.join(sandbox.path, 'pre_build_ios.sh');
      File(scriptPath).writeAsStringSync(realScript.readAsStringSync());
      stubBin = Directory(p.join(sandbox.path, 'bin'))..createSync();
      stubLogs = Directory(p.join(sandbox.path, 'logs'))..createSync();
      Directory(p.join(sandbox.path, 'home')).createSync();
      installStub('flutter');
      installStub('pod');
    });

    tearDown(() {
      sandbox.deleteSync(recursive: true);
    });

    test('never invokes flutter, which would reset the Swift package floor '
        'to iOS 13.0', () {
      final now = DateTime.now();
      writeFile('ios/Podfile.lock', now.subtract(const Duration(hours: 1)));
      writeFile('ios/Pods/Manifest.lock', now);

      expectSuccess(runScript());

      final flutterLog = stubLog('flutter');
      final invocations = flutterLog.existsSync()
          ? flutterLog.readAsStringSync()
          : '';
      expect(
        flutterLog.existsSync(),
        isFalse,
        reason: 'flutter was invoked with: $invocations',
      );
    });

    test('skips pod install when Pods/Manifest.lock is as new as '
        'Podfile.lock', () {
      final now = DateTime.now();
      writeFile('ios/Podfile.lock', now.subtract(const Duration(hours: 1)));
      writeFile('ios/Pods/Manifest.lock', now);

      final result = runScript();

      expectSuccess(result);
      expect(stubLog('pod').existsSync(), isFalse);
      expect(result.stdout, contains('CocoaPods dependencies are up to date'));
    });

    test('runs pod install when Podfile.lock is newer than '
        'Pods/Manifest.lock', () {
      final now = DateTime.now();
      writeFile(
        'ios/Pods/Manifest.lock',
        now.subtract(const Duration(hours: 1)),
      );
      writeFile('ios/Podfile.lock', now);

      expectSuccess(runScript());

      expect(stubLog('pod').readAsStringSync(), contains('install'));
    });

    test('runs pod install when Pods has never been installed', () {
      writeFile('ios/Podfile.lock', DateTime.now());

      expectSuccess(runScript());

      expect(stubLog('pod').readAsStringSync(), contains('install'));
    });
  });
}
