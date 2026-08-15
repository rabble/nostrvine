// ABOUTME: Freezes the share sheet behind lib/utils/share_sheet.dart so no
// ABOUTME: call site can present a share without a sharePositionOrigin.

import 'dart:io';

import 'package:test/test.dart';

/// The one file allowed to reach for the plugin directly, because it is what
/// fills the anchor for everybody else.
const _entryPoint = 'lib/utils/share_sheet.dart';

/// Any `import`/`export` of the plugin or of its platform interface.
///
/// The prefix deliberately stops at `share_plus` so it also catches
/// `package:share_plus_platform_interface/...`, whose `SharePlatform.instance`
/// reaches the same native channel without ever naming `SharePlus`.
final _sharePlusDirective = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:share_plus''',
  multiLine: true,
);

/// The plugin entry points that skip the anchor.
///
/// `SharePlus.instance`, `SharePlus.custom`, a stored `final s = SharePlus…`
/// and the whitespace form `SharePlus . instance` all contain the class name,
/// so matching the bare identifier covers the family rather than one spelling.
/// The deprecated `Share` statics are unreachable once the directive check
/// above passes, since they cannot be named without importing the plugin.
final _pluginEntryPoint = RegExp(r'\bSharePlus\b');

/// Every Dart file that ships in the app or in a workspace package.
///
/// Package `test/` and `example/` trees are excluded: they may exercise the
/// plugin directly, and they never run on a user's iPad.
List<File> _shippedDartFiles() {
  final roots = <Directory>[
    Directory('lib'),
    for (final entity in Directory('packages').listSync())
      if (entity is Directory) Directory('${entity.path}/lib'),
  ];

  return [
    for (final root in roots)
      if (root.existsSync())
        ...root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
  ];
}

String _relative(File file) => file.path.replaceAll(r'\', '/');

void main() {
  group('share sheet entry point', () {
    late List<File> files;

    setUpAll(() {
      files = _shippedDartFiles();
    });

    test('finds the files it is supposed to be scanning', () {
      // A scan that silently walks an empty tree would pass forever. Both
      // roots must actually contribute, and the entry point must be among
      // them, or the two guards below prove nothing.
      expect(files, isNotEmpty);
      expect(
        files.where((file) => _relative(file).startsWith('packages/')),
        isNotEmpty,
        reason: 'packages/*/lib is not being scanned',
      );
      expect(
        files.map(_relative),
        contains(_entryPoint),
        reason: 'the entry point itself is not being scanned',
      );
    });

    test('only the wrapper imports share_plus', () {
      final offenders = <String>[
        for (final file in files)
          if (_relative(file) != _entryPoint &&
              _sharePlusDirective.hasMatch(file.readAsStringSync()))
            _relative(file),
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'iPad rejects a share whose sharePositionOrigin is missing '
            '(#7506). Import $_entryPoint instead — it re-exports '
            'ShareParams, ShareResult, ShareResultStatus, XFile and '
            'CupertinoActivityType — then call showShareSheet(context, '
            'params), or showShareSheetAtOrigin when the anchor was resolved '
            'before an await.',
      );
    });

    test('only the wrapper names SharePlus', () {
      // Second line of defence: if the entry point ever re-exported SharePlus
      // itself, the import check above would still pass while every call site
      // regained an unanchored path to the plugin.
      final offenders = <String>[
        for (final file in files)
          if (_relative(file) != _entryPoint &&
              _pluginEntryPoint.hasMatch(file.readAsStringSync()))
            _relative(file),
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'SharePlus presents the share sheet without an anchor, which '
            'iPad refuses (#7506). Only $_entryPoint may name it, and it '
            'must not re-export it.',
      );
    });
  });
}
