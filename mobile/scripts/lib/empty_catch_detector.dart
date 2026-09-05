// ABOUTME: AST detector behind check_empty_catch_ceiling.sh.
// ABOUTME: Finds undocumented empty catch bodies across app and package libraries.
//
// Usage (from mobile/):
//   dart run scripts/lib/empty_catch_detector.dart <scan-dir>... \
//     [--path-prefix <dir>] [--detail]
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// An empty catch silently discards a failure. A catch body with no statements
// is counted unless it contains a line or block comment documenting why the
// no-op is intentional. This covers `catch (e) {}`, `catch (e, st) {}`,
// `on Foo catch (e) {}`, and `on Foo {}` regardless of line wrapping.
//
// Why an AST and not a regex
// --------------------------
// Dart format may place the braces on different lines, and `on Foo {}` has no
// `catch` token at all. Conversely, catch-like text in a comment or string is
// not executable code. The AST identifies every CatchClause independent of
// formatting; its token stream preserves comments so documented no-ops remain
// explicitly allowed.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

bool shouldScanEmptyCatchFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.contains('test') || segments.contains('integration_test')) {
    return false;
  }
  final packagesIndex = segments.indexOf('packages');
  if (packagesIndex >= 0 &&
      (segments.length <= packagesIndex + 2 ||
          segments[packagesIndex + 2] != 'lib')) {
    return false;
  }
  return normalized.endsWith('.dart') && !_isGenerated(normalized);
}

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.mocks.dart') ||
    path.contains('/l10n/generated/') ||
    path.contains('/.dart_tool/') ||
    path.contains('/build/');

class EmptyCatchSite {
  const EmptyCatchSite({required this.line, required this.snippet});

  final int line;
  final String snippet;
}

List<EmptyCatchSite> findEmptyCatchesInSource(
  String source, {
  required String path,
}) {
  final ParseStringResult parsed;
  try {
    parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
  } on Object {
    return const [];
  }
  final visitor = _EmptyCatchVisitor(parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _EmptyCatchVisitor extends RecursiveAstVisitor<void> {
  _EmptyCatchVisitor(this._lineInfo);

  final LineInfo _lineInfo;
  final List<EmptyCatchSite> sites = [];

  @override
  void visitCatchClause(CatchClause node) {
    super.visitCatchClause(node);
    final body = node.body;
    if (body.statements.isNotEmpty || _hasBodyComment(body)) return;

    sites.add(
      EmptyCatchSite(
        line: _lineInfo.getLocation(node.offset).lineNumber,
        snippet: node.toString().replaceAll(RegExp(r'\s+'), ' '),
      ),
    );
  }

  /// A statement-free block holds only its two braces, so every comment inside
  /// it precedes `}`, and a comment before `{` belongs to the clause instead.
  /// This is the exemption the SDK's `empty_catches` lint applies too.
  bool _hasBodyComment(Block body) =>
      body.rightBracket.precedingComments != null;
}

void main(List<String> args) {
  final scanDirs = <String>[];
  var pathPrefix = '';
  var detail = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        if (++i >= args.length) _usage();
        pathPrefix = args[i];
      case '--detail':
        detail = true;
      default:
        if (args[i].startsWith('--')) _usage();
        scanDirs.add(args[i]);
    }
  }
  if (scanDirs.isEmpty) _usage();

  final counts = <String, int>{};
  final details = <String>[];
  for (final scanDir in scanDirs) {
    final directory = Directory(scanDir);
    if (!directory.existsSync()) {
      stderr.writeln('empty_catch_detector: no such dir: $scanDir');
      exit(2);
    }
    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => shouldScanEmptyCatchFile(file.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final sites = findEmptyCatchesInSource(
        file.readAsStringSync(),
        path: file.path,
      );
      if (sites.isEmpty) continue;

      var relative = file.path;
      if (pathPrefix.isNotEmpty && relative.startsWith(pathPrefix)) {
        relative = relative.substring(pathPrefix.length);
      }
      relative = relative.replaceFirst(RegExp('^/'), '');
      counts[relative] = (counts[relative] ?? 0) + sites.length;
      for (final site in sites) {
        details.add('$relative:${site.line}  ${site.snippet}');
      }
    }
  }

  if (detail) {
    (details..sort()).forEach(stdout.writeln);
    return;
  }
  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

Never _usage() {
  stderr.writeln(
    'usage: empty_catch_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
