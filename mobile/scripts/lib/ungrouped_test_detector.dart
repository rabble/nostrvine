// ABOUTME: Detector behind check_ungrouped_tests.sh — finds test declarations
// ABOUTME: that sit outside any group(), i.e. flat test files (#3615).
//
// Usage (from mobile/):
//   dart run scripts/lib/ungrouped_test_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A `test`, `testWidgets`, `blocTest` or `patrolTest` invocation with no
// enclosing `group(...)` call. `group` nesting is tracked lexically, so a test
// inside `group(A, () { group('b', () { ... }) })` is grouped at any depth.
//
// Why an AST and not a regex
// --------------------------
// Grouping is a nesting property, and nesting is exactly what a line-oriented
// scan cannot see. Indentation is a poor proxy: `dart format` wraps long
// argument lists, so a grouped test's `testWidgets(` can start at the same
// column as an ungrouped one in a neighbouring file. A brace counter fares no
// better, since braces appear inside strings, comments, and `${}`
// interpolations. The parser already resolves all of that.
//
// Only unqualified calls count — `harness.test(...)` is a method on some other
// object, not a declaration the test runner picks up.
//
// Test-declaring HELPERS are counted at their call site, not their definition.
// A wrapper like
//
//     void testWidgetsWithSurfaceSize(String description, cb) {
//       testWidgets(description, (tester) async { ... });
//     }
//
// declares nothing on its own — the runner registers a case only where the
// wrapper is called, so that is where grouping is decided. Counting the body
// would permanently flag three files whose `main()` is fully grouped, and
// skipping the shape entirely would let a helper called from top-level `main`
// slip through. Helper names are resolved to a fixpoint, so a wrapper around a
// wrapper is still counted at the outermost call.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Calls that declare a test case to the runner.
const _testDeclarations = {'test', 'testWidgets', 'blocTest', 'patrolTest'};

/// One test declaration with no enclosing `group(...)`.
class UngroupedTest {
  UngroupedTest({
    required this.path,
    required this.line,
    required this.declaration,
    required this.description,
  });

  final String path;
  final int line;

  /// `test`, `testWidgets`, `blocTest` or `patrolTest`.
  final String declaration;

  /// The first argument's source, truncated — enough to find the test by eye.
  final String description;
}

void main(List<String> args) {
  final positional = <String>[];
  var pathPrefix = '';
  var detail = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        pathPrefix = i + 1 < args.length ? args[++i] : '';
      case '--detail':
        detail = true;
      default:
        positional.add(args[i]);
    }
  }
  if (positional.isEmpty) {
    stderr.writeln(
      'usage: ungrouped_test_detector.dart <scan-dir>... '
      '[--path-prefix <dir>] [--detail]',
    );
    exit(2);
  }
  final dirs = <Directory>[];
  for (final path in positional) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      stderr.writeln('not a directory: $path');
      exit(2);
    }
    dirs.add(dir);
  }
  if (pathPrefix.isEmpty) pathPrefix = dirs.first.path;

  final sites = findUngroupedTests(dirs, pathPrefix: pathPrefix);
  if (detail) {
    for (final site in sites) {
      stdout.writeln(
        '${site.path}:${site.line}\t${site.declaration}\t${site.description}',
      );
    }
    return;
  }
  final counts = <String, int>{};
  for (final site in sites) {
    counts[site.path] = (counts[site.path] ?? 0) + 1;
  }
  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

/// Scans every `*_test.dart` file under [dirs] and returns the ungrouped test
/// declarations in path-then-line order.
List<UngroupedTest> findUngroupedTests(
  List<Directory> dirs, {
  required String pathPrefix,
}) {
  final files = <File>[];
  for (final dir in dirs) {
    files.addAll(
      dir.listSync(recursive: true).whereType<File>().where(isTestFile),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  final sites = <UngroupedTest>[];
  for (final file in files) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file somebody cleaned up.
      stderr.writeln('ungrouped_test_detector: skipped ${file.path} ($error)');
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(findUngroupedTestsInSource(source, path: relative));
  }
  return sites;
}

/// True for a file the Dart test runner would pick up as a suite.
///
/// `*_test.dart` alone is not enough: `packages/nostr_sdk/lib/signer/`
/// `signer_test.dart` is library code, and `test_driver/integration_test.dart`
/// is the driver entry point. Both are invisible to the runner, so neither is
/// held to the grouping rule.
///
/// Matching is per path SEGMENT, not `contains('/test/')` — a scan rooted at a
/// relative `test` yields `test/foo_test.dart`, which has no leading slash and
/// would silently match nothing.
bool isTestFile(File file) {
  final path = file.path;
  if (!path.endsWith('_test.dart')) return false;
  final segments = path.split('/');
  final directories = segments.sublist(0, segments.length - 1);
  if (directories.any(_excludedDirectories.contains)) return false;
  return directories.any(_testDirectories.contains);
}

const _testDirectories = {'test', 'integration_test'};
const _excludedDirectories = {'.dart_tool', 'build', '.worktrees'};

/// Parses [source] and returns every test declaration with no enclosing group.
List<UngroupedTest> findUngroupedTestsInSource(
  String source, {
  required String path,
}) {
  final parsed = parseString(
    content: source,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _UngroupedTestVisitor(
    path: path,
    lineInfo: parsed.lineInfo,
    helpers: _testDeclaringHelpers(parsed.unit),
  );
  parsed.unit.accept(visitor);
  return visitor.sites;
}

/// Names of functions that declare a test case when called.
///
/// Resolved to a fixpoint so a wrapper around a wrapper still resolves. `main`
/// is never a helper: it is the entry point, so a declaration in its body is
/// registered directly.
Set<String> _testDeclaringHelpers(CompilationUnit unit) {
  final helpers = <String>{};
  while (true) {
    final finder = _HelperFinder(helpers);
    unit.accept(finder);
    if (finder.found.length == helpers.length) return helpers;
    helpers
      ..clear()
      ..addAll(finder.found);
  }
}

class _HelperFinder extends RecursiveAstVisitor<void> {
  _HelperFinder(this._known);

  final Set<String> _known;
  final found = <String>{};

  String? _enclosing;
  int _groupDepth = 0;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final previousEnclosing = _enclosing;
    final previousDepth = _groupDepth;
    final name = node.name.lexeme;
    _enclosing = name == 'main' ? null : name;
    // Depth is per function body: a helper called from inside a group is a
    // different question from what the helper itself declares.
    _groupDepth = 0;
    super.visitFunctionDeclaration(node);
    _enclosing = previousEnclosing;
    _groupDepth = previousDepth;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.realTarget == null && node.methodName.name == 'group') {
      _groupDepth++;
      super.visitMethodInvocation(node);
      _groupDepth--;
      return;
    }
    final enclosing = _enclosing;
    // A function whose declarations all sit inside its own group() registers a
    // group, not a loose test — calling it outside a group is correct, so it is
    // not a helper for our purposes.
    if (enclosing != null &&
        _groupDepth == 0 &&
        node.realTarget == null &&
        (_testDeclarations.contains(node.methodName.name) ||
            _known.contains(node.methodName.name))) {
      found.add(enclosing);
    }
    super.visitMethodInvocation(node);
  }
}

class _UngroupedTestVisitor extends RecursiveAstVisitor<void> {
  _UngroupedTestVisitor({
    required this.path,
    required this.lineInfo,
    required this.helpers,
  });

  final String path;
  final LineInfo lineInfo;

  /// Functions that declare a test when called; see [_testDeclaringHelpers].
  final Set<String> helpers;
  final sites = <UngroupedTest>[];

  int _groupDepth = 0;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // A helper's body declares nothing until somebody calls it, and the call
    // site is what decides grouping.
    if (helpers.contains(node.name.lexeme)) return;
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `harness.test(...)` is a method on another object, not a declaration.
    final isBareCall = node.realTarget == null;
    final name = node.methodName.name;
    if (isBareCall && name == 'group') {
      _groupDepth++;
      super.visitMethodInvocation(node);
      _groupDepth--;
      return;
    }
    final declares = _testDeclarations.contains(name) || helpers.contains(name);
    if (isBareCall && _groupDepth == 0 && declares) {
      sites.add(
        UngroupedTest(
          path: path,
          line: lineInfo.getLocation(node.offset).lineNumber,
          declaration: name,
          description: _describe(node),
        ),
      );
    }
    super.visitMethodInvocation(node);
  }

  String _describe(MethodInvocation node) {
    final args = node.argumentList.arguments;
    if (args.isEmpty) return '';
    final text = args.first.toSource().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 70 ? text : '${text.substring(0, 67)}...';
  }
}
