// ABOUTME: Detector behind check_nostr_id_log_truncation.sh — finds Nostr
// ABOUTME: identifiers that are shortened on their way into a log/debug sink.
//
// Usage (from mobile/):
//   dart run scripts/lib/nostr_id_log_truncation_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A site is a Nostr identifier that is SHORTENED and then reaches a logging
// sink. Both halves are required, which is the whole point: shortening an
// identifier for the UI is allowed (AGENTS.md lets layout handle overflow),
// and logging an identifier is required (AGENTS.md: "Never truncate Nostr IDs
// in code, logs, tests, analytics, or debug output. Use full values").
//
//   Log.info('event ${event.id.substring(0, 8)}...')   COUNTED
//   Text(NostrKeyUtils.truncateNpub(pubkey))           not counted — UI sink
//   Log.info('event ${event.id}')                      not counted — full value
//
// Shortening shapes recognised:
//   • `<id>.substring(...)`  / `<id>.take(n)` / `<id>.characters.take(n)`
//   • a call to a SHORTENER declared in the same file — a function or method
//     whose body substrings/takes one of its own parameters. That is how
//     `_maskKey(_npub)` is caught: the truncation is one frame away from the
//     log call, so a purely local check would miss it.
//   • the same, one hop through a local variable: `final p = id.substring(...)`
//     then `Log.debug('... $p')`. Three of the four sites this guard was built
//     for used exactly that shape, so it is not an optional refinement.
//
// Sinks recognised: `Log.<level>`, `developer.log` (qualified or bare — the
// SDK imports dart:developer unprefixed), `debugPrint`, `print`, and
// package:logging levels on a receiver named log/_log/logger/_logger.
//
// Why an AST and not a grep
// -------------------------
// A grep cannot separate the three cases above. `substring` and `...` are both
// overwhelmingly legitimate — the repo has ~60 substring call sites and every
// prose ellipsis ("Publishing Nostr event...") sits inside a real log line, so
// a text rule is either blind or all false positives. The signal is the PATH
// from a truncation to a log call, and a path is a tree property.
//
// Limits, stated plainly
// ----------------------
// The AST is UNRESOLVED (parseString, like its sibling detectors), so "is this
// a Nostr identifier" is decided by NAME, from [_identifierLexicon] below. That
// lexicon IS the contract: a value not named like an identifier is not seen,
// and shortening reached through two hops of helper indirection is not seen.
// Both are deliberate — the guard exists to stop the shapes that actually
// recur, not to prove a theorem.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Names that mean "this value is a Nostr identifier".
///
/// Matched against the whole identifier lowercased AND against its last
/// camelCase segment, so `eventId`, `giftWrapId` and `targetEventId` all reach
/// `id` without being enumerated. Grounded in the protocol vocabulary:
/// NIP-01 gives `id` / `pubkey` / `sig`, NIP-19 gives the bech32 prefixes,
/// NIP-42 gives the AUTH `challenge`, and the Blossom `x` tag carries
/// `sha256Hash`.
///
/// `hash` alone is intentionally absent: a blurhash is not an identifier, and
/// widening this set to catch one Blossom variable would flag it.
const _identifierLexicon = {
  'id',
  'ids',
  'eventid',
  'pubkey',
  'pubkeys',
  'pubkeyhex',
  'hexpubkey',
  'publickey',
  'privatekey',
  'npub',
  'nsec',
  'note',
  'nevent',
  'naddr',
  'nprofile',
  'nrelay',
  'sig',
  'signature',
  'coordinate',
  'dtag',
  'challenge',
  'sha256hash',
  'blobhash',
};

/// String members that shorten their receiver.
///
/// `take` only qualifies through a character view (see [_characterViews]).
/// `ids.take(3)` on a List is SAMPLING — it logs three whole identifiers, which
/// is exactly what this guard wants — so counting it would be backwards. Both
/// live examples in this repo are that shape.
const _shorteningMembers = {'substring', 'take'};

/// Views that turn a String into per-character elements, so a `take` over one
/// really does cut an identifier in half.
const _characterViews = {'characters', 'runes', 'codeUnits', 'split'};

/// `Log.<level>(...)` — the app-wide UnifiedLogger typedef.
const _unifiedLogLevels = {'verbose', 'debug', 'info', 'warning', 'error'};

/// package:logging levels, reached on a logger-shaped receiver.
const _loggingPackageLevels = {
  'finest',
  'finer',
  'fine',
  'config',
  'info',
  'warning',
  'severe',
  'shout',
  'log',
};

/// Receivers that are loggers rather than domain objects.
const _loggerReceivers = {'log', '_log', 'logger', '_logger', 'developer'};

/// Unqualified functions that write to a diagnostic sink.
const _bareLogFunctions = {'log', 'print', 'debugPrint'};

/// Cheap substrings that must appear in a file for it to hold a log sink.
///
/// DERIVED from the sink sets rather than written out, because a hand-written
/// prefilter silently un-guards whatever it forgets: an earlier draft listed
/// `log.` and so skipped every file logging through `logger.warning`, and the
/// only symptom was zero findings.
final _sinkTokens = <String>{
  'Log.',
  for (final r in _loggerReceivers) '$r.',
  for (final f in _bareLogFunctions) '$f(',
};

/// One shortened Nostr identifier reaching a log sink.
class TruncationSite {
  TruncationSite({
    required this.path,
    required this.line,
    required this.identifier,
    required this.how,
    required this.sink,
  });

  final String path;
  final int line;

  /// The identifier being shortened, as written.
  final String identifier;

  /// `substring` / `take`, or the shortener function's name.
  final String how;

  /// The log call it reaches.
  final String sink;
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
      'usage: nostr_id_log_truncation_detector.dart <scan-dir>... '
      '[--path-prefix <dir>] [--detail]',
    );
    exit(2);
  }
  final dirs = <Directory>[];
  for (final p in positional) {
    final dir = Directory(p);
    if (!dir.existsSync()) {
      stderr.writeln('not a directory: $p');
      exit(2);
    }
    dirs.add(dir);
  }
  if (pathPrefix.isEmpty) pathPrefix = dirs.first.path;

  final sites = <TruncationSite>[];
  for (final dir in dirs) {
    sites.addAll(findTruncationSites(dir, pathPrefix: pathPrefix));
  }
  sites.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });

  if (detail) {
    for (final s in sites) {
      stdout.writeln(
        '${s.path}:${s.line}\t${s.identifier}\t${s.how}\t${s.sink}',
      );
    }
    return;
  }
  final counts = <String, int>{};
  for (final s in sites) {
    counts[s.path] = (counts[s.path] ?? 0) + 1;
  }
  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

/// Scans every non-generated Dart file under [dir], in path-then-line order.
List<TruncationSite> findTruncationSites(
  Directory dir, {
  required String pathPrefix,
}) {
  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('/l10n/generated/'))
          .where((f) => !f.path.contains('/.dart_tool/'))
          .where((f) => !f.path.contains('/build/'))
          .where(
            (f) => !const [
              '.g.dart',
              '.freezed.dart',
              '.gr.dart',
              '.config.dart',
              '.mocks.dart',
            ].any(f.path.endsWith),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sites = <TruncationSite>[];
  for (final file in files) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file that was cleaned up.
      stderr.writeln(
        'nostr_id_log_truncation: unreadable ${file.path} ($error)',
      );
      continue;
    }
    // A site needs a shortening call AND a log sink in the same file. This
    // prefilter drops ~2300 of the ~2350 files under lib/ and packages/*/lib.
    final shortens = _shorteningMembers.any((m) => source.contains('$m('));
    if (!shortens) continue;
    if (!_sinkTokens.any(source.contains)) continue;

    final ParseStringResult parsed;
    try {
      parsed = parseString(
        content: source,
        path: file.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
    } on Object catch (error) {
      stderr.writeln('nostr_id_log_truncation: skipped ${file.path} ($error)');
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(
      findSitesInUnit(parsed.unit, parsed.lineInfo, path: relative),
    );
  }
  return sites;
}

/// Finds the sites in one already-parsed compilation unit.
List<TruncationSite> findSitesInUnit(
  CompilationUnit unit,
  LineInfo lineInfo, {
  required String path,
}) {
  final shorteners = _ShortenerCollector()..visitCompilationUnit(unit);
  final visitor = _SiteCollector(
    path: path,
    lineInfo: lineInfo,
    shorteners: shorteners.names,
  );
  unit.accept(visitor);
  return visitor.sites;
}

/// True when [name] reads as a Nostr identifier.
///
/// Matches the whole name lowercased, or its last camelCase segment, so
/// `eventId` / `giftWrapId` / `targetEventId` all reach `id`.
bool isIdentifierName(String name) {
  final bare = name.startsWith('_') ? name.substring(1) : name;
  if (bare.isEmpty) return false;
  if (_identifierLexicon.contains(bare.toLowerCase())) return true;
  // Last camelCase segment: index of the final uppercase run start.
  var cut = -1;
  for (var i = bare.length - 1; i > 0; i--) {
    final c = bare.codeUnitAt(i);
    if (c >= 0x41 && c <= 0x5A) {
      cut = i;
      break;
    }
  }
  if (cut <= 0) return false;
  return _identifierLexicon.contains(bare.substring(cut).toLowerCase());
}

/// The identifier name an expression ultimately reads, or null.
///
/// `event.id` -> `id`; `_npub` -> `_npub`; `widget.video.pubkey` -> `pubkey`;
/// `event.id!` -> `id`. Returns the *written* name so reports quote source.
String? _rootIdentifierName(Expression? expr) {
  return switch (expr) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    PostfixExpression(:final operand) => _rootIdentifierName(operand),
    ParenthesizedExpression(:final expression) => _rootIdentifierName(
      expression,
    ),
    _ => null,
  };
}

/// The identifier [node] shortens, or null when [node] is not a shortening.
///
/// Centralises the `take`-through-a-character-view rule so the shortener probe
/// and the site finder can never disagree about what counts.
String? shortenedRootName(MethodInvocation node) {
  final member = node.methodName.name;
  if (!_shorteningMembers.contains(member)) return null;
  final target = node.realTarget;
  if (member == 'substring') return _rootIdentifierName(target);

  final view = switch (target) {
    PropertyAccess(:final propertyName) => propertyName.name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    MethodInvocation(:final methodName) => methodName.name,
    _ => null,
  };
  if (view == null || !_characterViews.contains(view)) return null;
  final beneath = switch (target) {
    PropertyAccess(:final target) => target,
    PrefixedIdentifier(:final prefix) => prefix,
    MethodInvocation(:final realTarget) => realTarget,
    _ => null,
  };
  return _rootIdentifierName(beneath);
}

/// Collects functions in this unit that shorten one of their own parameters.
///
/// `_maskKey(String key) => '${key.substring(0, 8)}...'` registers `_maskKey`,
/// so `_log.fine('… ${_maskKey(_npub)}')` is seen as a truncation of `_npub`.
class _ShortenerCollector extends RecursiveAstVisitor<void> {
  final names = <String>{};

  void _record(String name, FormalParameterList? params, AstNode? body) {
    if (params == null || body == null) return;
    final paramNames = <String>{
      for (final p in params.parameters) ?p.name?.lexeme,
    };
    if (paramNames.isEmpty) return;
    final probe = _ShorteningProbe(paramNames);
    body.accept(probe);
    if (probe.found) names.add(name);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _record(node.name.lexeme, node.parameters, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _record(
      node.name.lexeme,
      node.functionExpression.parameters,
      node.functionExpression.body,
    );
    super.visitFunctionDeclaration(node);
  }
}

/// True once it sees `<oneOfThese>.substring(...)` / `.take(...)`.
class _ShorteningProbe extends RecursiveAstVisitor<void> {
  _ShorteningProbe(this._params);

  final Set<String> _params;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final root = shortenedRootName(node);
    if (root != null && _params.contains(root)) found = true;
    super.visitMethodInvocation(node);
  }
}

/// Walks a unit and records every shortened identifier reaching a log sink.
class _SiteCollector extends RecursiveAstVisitor<void> {
  _SiteCollector({
    required this.path,
    required this.lineInfo,
    required this.shorteners,
  });

  final String path;
  final LineInfo lineInfo;
  final Set<String> shorteners;
  final sites = <TruncationSite>[];

  /// Source offsets already reported, so a log call nested inside another
  /// log call's arguments is not counted twice.
  final _seen = <int>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final sink = _logSinkName(node);
    if (sink != null) _scanLogCall(node, sink);
    super.visitMethodInvocation(node);
  }

  /// The sink label for [node] if it writes to a diagnostic sink, else null.
  String? _logSinkName(MethodInvocation node) {
    final member = node.methodName.name;
    final target = node.realTarget;
    if (target == null) {
      return _bareLogFunctions.contains(member) ? member : null;
    }
    final receiver = _rootIdentifierName(target);
    if (receiver == null) return null;
    if (receiver == 'Log' && _unifiedLogLevels.contains(member)) {
      return 'Log.$member';
    }
    if (receiver == 'developer' && member == 'log') return 'developer.log';
    if (_loggerReceivers.contains(receiver) &&
        _loggingPackageLevels.contains(member)) {
      return '$receiver.$member';
    }
    return null;
  }

  void _scanLogCall(MethodInvocation call, String sink) {
    final locals = _shortenedLocalsAround(call);
    final finder = _ShorteningFinder(shorteners: shorteners, locals: locals);
    call.argumentList.accept(finder);
    for (final hit in finder.hits) {
      if (!_seen.add(hit.offset)) continue;
      sites.add(
        TruncationSite(
          path: path,
          line: lineInfo.getLocation(hit.offset).lineNumber,
          identifier: hit.identifier,
          how: hit.how,
          sink: sink,
        ),
      );
    }
  }

  /// Locals declared in [node]'s enclosing function body whose initializer
  /// shortens a Nostr identifier — the `final preview = id.substring(0, 8)`
  /// hop that sits between the truncation and the log call.
  Map<String, _Hit> _shortenedLocalsAround(AstNode node) {
    AstNode? scope = node;
    while (scope != null && scope is! FunctionBody) {
      scope = scope.parent;
    }
    if (scope == null) return const {};
    final collector = _ShortenedLocalCollector(shorteners);
    scope.accept(collector);
    return collector.locals;
  }
}

/// A shortened identifier found inside a log call's arguments.
class _Hit {
  const _Hit({
    required this.offset,
    required this.identifier,
    required this.how,
  });

  final int offset;
  final String identifier;
  final String how;
}

/// Records locals whose initializer shortens a Nostr identifier.
class _ShortenedLocalCollector extends RecursiveAstVisitor<void> {
  _ShortenedLocalCollector(this._shorteners);

  final Set<String> _shorteners;
  final locals = <String, _Hit>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer != null) {
      // Probe the whole initializer: the shortening is often inside a
      // conditional guard, e.g. `x.length > 8 ? x.substring(0, 8) : x`.
      final finder = _ShorteningFinder(
        shorteners: _shorteners,
        locals: const {},
      );
      initializer.accept(finder);
      if (finder.hits.isNotEmpty) {
        final first = finder.hits.first;
        locals[node.name.lexeme] = _Hit(
          offset: node.offset,
          identifier: first.identifier,
          how: first.how,
        );
      }
    }
    super.visitVariableDeclaration(node);
  }
}

/// Finds shortened Nostr identifiers inside an arbitrary subtree.
class _ShorteningFinder extends RecursiveAstVisitor<void> {
  _ShorteningFinder({required this.shorteners, required this.locals});

  final Set<String> shorteners;
  final Map<String, _Hit> locals;
  final hits = <_Hit>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final member = node.methodName.name;
    final shortened = shortenedRootName(node);
    if (shortened != null) {
      if (isIdentifierName(shortened)) {
        hits.add(_Hit(offset: node.offset, identifier: shortened, how: member));
      }
    } else if (shorteners.contains(member)) {
      for (final arg in node.argumentList.arguments) {
        final value = arg is NamedExpression ? arg.expression : arg;
        final root = _rootIdentifierName(value);
        if (root != null && isIdentifierName(root)) {
          hits.add(_Hit(offset: node.offset, identifier: root, how: member));
          break;
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // A reference to a local that was assigned a shortened identifier.
    final local = locals[node.name];
    if (local != null) {
      hits.add(
        _Hit(offset: node.offset, identifier: local.identifier, how: local.how),
      );
    }
    super.visitSimpleIdentifier(node);
  }
}
