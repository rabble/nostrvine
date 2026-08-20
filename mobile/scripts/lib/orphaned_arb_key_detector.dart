// ABOUTME: Detector behind check_orphaned_arb_key_floor.sh — lists app_en.arb
// ABOUTME: keys that no non-generated Dart file references (#3630).

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Path fragment of the gen-l10n output directory, in host separators.
///
/// Every key appears there by construction — that is what gen-l10n emits — so
/// scanning it would report zero orphans forever.
final String generatedSegment = _joined(['lib', 'l10n', 'generated', '']);

final String _dartToolSegment = _joined(['', '.dart_tool', '']);

String _joined(List<String> parts) => parts.join(Platform.pathSeparator);

/// Collects every identifier that [source] mentions *as code*.
///
/// Comments and string-literal bodies are excluded, so a `// TODO wire up
/// feedSkip` or a `Log.info('feedSkip')` does not keep a dead key alive.
/// Interpolated expressions ARE code and are collected, so `'${l10n.feedSkip}'`
/// counts.
///
/// A dartdoc square-bracket reference — `/// Renders [feedSkip].` — needs an
/// explicit skip: the parser resolves it to a real [SimpleIdentifier] inside a
/// [CommentReference], so without this the detector would quietly accept a
/// doc mention as a render.
///
/// Returns an empty set when [source] does not parse; a file the analyzer
/// cannot read is a pre-existing problem for `flutter analyze`, and treating it
/// as "references nothing" only ever over-reports orphans, which the baseline
/// review catches.
Set<String> collectCodeIdentifiers(String source) {
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _IdentifierCollector();
  parsed.unit.accept(visitor);
  return visitor.identifiers;
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final identifiers = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  /// Prunes the subtree: a `[name]` inside dartdoc is documentation, not a
  /// render. Deliberately does not call `super`.
  @override
  void visitCommentReference(CommentReference node) {}
}

/// Returns the sorted [arb] message keys absent from [referenced].
///
/// `@`-prefixed metadata entries and the `@@locale` header are not messages and
/// are never reported.
List<String> findOrphanedArbKeys({
  required Map<String, dynamic> arb,
  required Set<String> referenced,
}) =>
    arb.keys
        .where((key) => !key.startsWith('@'))
        .where((key) => !referenced.contains(key))
        .toList()
      ..sort();

/// Every `.dart` file under [roots], skipping gen-l10n output and build caches.
Iterable<File> dartSourcesUnder(List<Directory> roots) sync* {
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart')) continue;
      if (path.contains(generatedSegment)) continue;
      if (path.contains(_dartToolSegment)) continue;
      yield entity;
    }
  }
}

void main(List<String> args) {
  final detail = args.contains('--detail');
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final arbPath = positional.isNotEmpty
      ? positional.first
      : 'lib/l10n/app_en.arb';
  final scanRoots = positional.length > 1
      ? positional.sublist(1)
      : const ['lib', 'test', 'integration_test'];

  final arbFile = File(arbPath);
  if (!arbFile.existsSync()) {
    stderr.writeln('orphaned_arb_key_detector: no such file: $arbPath');
    exit(2);
  }
  final arb = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;

  // Only ARB keys are retained, so memory stays bounded by the template rather
  // than by every identifier in a 3200-file scan.
  final candidates = arb.keys.where((k) => !k.startsWith('@')).toSet();
  final referenced = <String>{};
  for (final file in dartSourcesUnder(scanRoots.map(Directory.new).toList())) {
    referenced.addAll(
      collectCodeIdentifiers(
        file.readAsStringSync(),
      ).where(candidates.contains),
    );
  }

  for (final key in findOrphanedArbKeys(arb: arb, referenced: referenced)) {
    stdout.writeln(detail ? '$key\t${jsonEncode(arb[key])}' : key);
  }
}
