// ABOUTME: Detector behind check_shared_setup_stubs.sh — finds mocktail stub
// ABOUTME: registrations in a setUp whose scope spans descendant groups (#8399).
//
// Usage (from mobile/):
//   dart run scripts/lib/shared_setup_stub_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --min-count <n>       only report files with at least n sites (default 0)
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A `when(...)` (or `whenListen(...)`) call inside a `setUp` / `setUpAll`
// callback whose enclosing scope also contains at least one DESCENDANT group
// that declares a test.
//
// That descendant condition is the whole rule. A stub in a leaf group's setUp
// governs only tests written a few lines below it, where a reader looking at a
// failing test can see it. A stub in a setUp that spans child groups is
// inherited by tests that never mention it and cannot see it — which is how
// #7324 stayed green across 421 tests in dm_repository_test.dart for months,
// and how that file's shared setUp grew from 6 stubs to 21 across 13 separate
// PRs without any one of them looking wrong in review.
//
// A `setUp` at `main()` level with no enclosing group counts whenever the file
// declares any group at all: its stubs reach every one of them.
//
// Only setUps at group-nesting depth 0 or 1 are counted -- file-level, or the
// body of a single outermost group like `group(DmRepository, ...)`. That is
// what "shared setUp" means in #8399, and it is where the reach is widest.
// Depth >= 2 accounts for 27 of 1,395 sites repo-wide, and a setUp that deep is
// already scoped to a narrow slice of one file.
//
// What does NOT count
// -------------------
// * A leaf group's own `setUp` — the stub and the tests it governs are adjacent.
// * `setUp` bodies with no `when(` at all — mock construction, fixture wiring,
//   `registerFallbackValue`, and channel handlers are not stubbed decisions.
// * A `when(` outside any `setUp` — a stub inside a test body is already local,
//   which is exactly the shape this ratchet pushes work toward.
//
// The count is deliberately blind to WHAT is stubbed. A stub standing in for a
// decision production branches on is the hazard; one that exists only because
// an unstubbed mocktail member throws is not. Nothing in the syntax separates
// them — that judgment lives in review, and in the comment the author writes
// next to the stub. The ceiling only insists the total may not grow.
//
// Why an AST and not a regex
// --------------------------
// Whether a setUp spans descendant groups is a nesting property, and nesting is
// what a line-oriented scan cannot see. `dart format` wraps long argument lists,
// so indentation does not track depth; and `when(` appears inside comments,
// string literals and `${}` interpolations, none of which register a stub.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const _setUpNames = {'setUp', 'setUpAll'};
const _stubNames = {'when', 'whenListen'};
const _testNames = {'test', 'testWidgets', 'blocTest', 'patrolTest'};

/// Deepest group nesting a setUp may sit at and still count as "shared".
const _maxDepth = 1;

/// One inherited stub registration.
class SharedSetupStub {
  SharedSetupStub(this.path, this.line, this.setUpName, this.scope, this.depth);

  final String path;
  final int line;
  final String setUpName;

  /// How many `group(...)` calls enclose the setUp. 0 = file-level.
  final int depth;

  /// Description of the scope the setUp governs, for --detail output.
  final String scope;
}

void main(List<String> args) {
  final dirs = <String>[];
  var pathPrefix = '';
  var detail = false;
  var minCount = 0;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        if (++i >= args.length) _usage();
        pathPrefix = args[i];
      case '--min-count':
        if (++i >= args.length) _usage();
        minCount = int.tryParse(args[i]) ?? _usage();
      case '--detail':
        detail = true;
      default:
        if (args[i].startsWith('-')) _usage();
        dirs.add(args[i]);
    }
  }
  if (dirs.isEmpty) _usage();

  final found = <SharedSetupStub>[];
  for (final dir in dirs) {
    final d = Directory(dir);
    if (!d.existsSync()) {
      stderr.writeln('shared_setup_stub_detector: no such directory: $dir');
      exit(2);
    }
    found.addAll(findSharedSetupStubs(d, pathPrefix: pathPrefix));
  }

  if (detail) {
    for (final s in found) {
      stdout.writeln(
        '${s.path}:${s.line}\td${s.depth}\t${s.setUpName}\t${s.scope}',
      );
    }
    return;
  }
  final counts = <String, int>{};
  for (final s in found) {
    counts[s.path] = (counts[s.path] ?? 0) + 1;
  }
  final paths = counts.keys.where((p) => counts[p]! >= minCount).toList()
    ..sort();
  for (final p in paths) {
    stdout.writeln('$p\t${counts[p]}');
  }
}

/// Every inherited shared-`setUp` stub registration under [dir], sorted by
/// path then line. Exposed for scripts/check_shared_setup_stubs.sh's test
/// (test/tools/shared_setup_stub_detector_test.dart).
List<SharedSetupStub> findSharedSetupStubs(
  Directory dir, {
  String pathPrefix = '',
}) {
  final found = <SharedSetupStub>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!_isTestFile(entity)) continue;
    found.addAll(_scan(entity, pathPrefix));
  }
  found.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });
  return found;
}

Never _usage() {
  stderr.writeln(
    'usage: dart run scripts/lib/shared_setup_stub_detector.dart <dir>... '
    '[--path-prefix <dir>] [--min-count <n>] [--detail]',
  );
  exit(2);
}

bool _isTestFile(File f) => f.path.endsWith('_test.dart');

List<SharedSetupStub> _scan(File file, String pathPrefix) {
  final content = file.readAsStringSync();
  final result = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  var rel = file.path;
  if (pathPrefix.isNotEmpty && rel.startsWith(pathPrefix)) {
    rel = rel.substring(pathPrefix.length);
    if (rel.startsWith('/')) rel = rel.substring(1);
  }
  final lineInfo = result.lineInfo;
  final visitor = _Visitor(rel, lineInfo);
  result.unit.accept(visitor);
  return visitor.found;
}

/// Name of an unqualified invocation, or null when it is a method on a target.
String? _plainName(MethodInvocation node) =>
    node.target == null ? node.methodName.name : null;

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.path, this.lineInfo);

  final String path;
  final dynamic lineInfo;
  final found = <SharedSetupStub>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = _plainName(node);
    if (name != null && _setUpNames.contains(name)) {
      // The scope this setUp governs is its nearest enclosing group body, or
      // the whole file when there is none.
      final scopeNode = _enclosingGroupBody(node) ?? node.root;
      final scopeLabel = scopeNode == node.root
          ? 'file'
          : _groupLabel(scopeNode) ?? 'group';
      if (_groupDepth(node) <= _maxDepth &&
          _hasDescendantGroupWithTest(scopeNode)) {
        for (final stub in _stubCalls(node)) {
          found.add(
            SharedSetupStub(
              path,
              lineInfo.getLocation(stub.offset).lineNumber as int,
              name,
              scopeLabel,
              _groupDepth(node),
            ),
          );
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  int _groupDepth(AstNode node) {
    var d = 0;
    for (var p = node.parent; p != null; p = p.parent) {
      if (p is MethodInvocation && _plainName(p) == 'group') d++;
    }
    return d;
  }

  /// The body of the innermost `group(...)` enclosing [node], if any.
  AstNode? _enclosingGroupBody(AstNode node) {
    for (var p = node.parent; p != null; p = p.parent) {
      if (p is MethodInvocation && _plainName(p) == 'group') return p;
    }
    return null;
  }

  String? _groupLabel(AstNode groupCall) {
    if (groupCall is! MethodInvocation) return null;
    final args = groupCall.argumentList.arguments;
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is SimpleStringLiteral) return first.value;
    return first.toString();
  }

  /// True when [scope] contains a `group(...)` (other than itself) whose body
  /// declares a test — i.e. the setUp's stubs are inherited by tests that do
  /// not sit beside it.
  bool _hasDescendantGroupWithTest(AstNode scope) {
    final finder = _DescendantGroupWithTestFinder(scope);
    scope.accept(finder);
    return finder.found;
  }

  /// The `when(...)` / `whenListen(...)` calls inside this setUp's callback.
  List<MethodInvocation> _stubCalls(MethodInvocation setUpCall) {
    final collector = _StubCollector();
    setUpCall.argumentList.accept(collector);
    return collector.calls;
  }
}

class _DescendantGroupWithTestFinder extends RecursiveAstVisitor<void> {
  _DescendantGroupWithTestFinder(this.scope);

  final AstNode scope;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found) return;
    if (identical(node, scope)) {
      super.visitMethodInvocation(node);
      return;
    }
    if (_plainName(node) == 'group') {
      final t = _TestFinder();
      node.argumentList.accept(t);
      if (t.found) {
        found = true;
        return;
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _TestFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found) return;
    final n = _plainName(node);
    if (n != null && _testNames.contains(n)) {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }
}

class _StubCollector extends RecursiveAstVisitor<void> {
  final calls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final n = _plainName(node);
    if (n != null && _stubNames.contains(n)) calls.add(node);
    super.visitMethodInvocation(node);
  }
}
