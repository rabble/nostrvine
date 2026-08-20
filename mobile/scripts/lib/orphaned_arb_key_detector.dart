// ABOUTME: Detector behind check_orphaned_arb_key_floor.sh — lists app_en.arb
// ABOUTME: keys that nothing under lib/ renders (#3630).

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

/// Collects the names in [source] that could be an `AppLocalizations` member.
///
/// Two shapes count, and only two:
///
/// 1. **A member access or a call on a target** — `l10n.fooKey`,
///    `context.l10n.fooKey`, `AppLocalizations.of(c)!.fooKey`,
///    `'${l10n.fooKey}'`, and `l10n.fooCount(n)`. A key with placeholders
///    generates a method rather than a getter, so the invocation form is not
///    optional. An interpolated expression is code, so it counts.
/// 2. **A bare identifier inside `extension ... on AppLocalizations`** —
///    `lib/l10n/publish_error_kind_l10n.dart` and its two siblings dispatch an
///    enum to a message with implicit `this` (`return publishErrorTimeout;`).
///    51 live keys reach the UI only that way, so a member-access-only
///    collector would report every one of them as dead.
///
/// A bare identifier ANYWHERE ELSE does not count, which is the whole point: a
/// local named `profileRefresh` in a widget must not keep the ARB key of that
/// name alive. Collecting every identifier instead — the obvious
/// implementation — makes the detector a lower bound rather than a decision,
/// because any key sharing a name with an ordinary Dart identifier can then
/// never be flagged.
///
/// Comments and string-literal bodies are excluded. A dartdoc square-bracket
/// reference — `/// Renders [fooKey].` — needs an explicit skip: the parser
/// resolves it to a real [SimpleIdentifier] inside a [CommentReference], so
/// without this the detector would quietly accept a doc mention as a render.
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

/// The type whose members are ARB keys.
const _localizationsClass = 'AppLocalizations';

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final identifiers = <String>{};

  /// Depth of `extension ... on AppLocalizations` bodies we are inside, where
  /// an unqualified identifier is an implicit-`this` member access.
  int _inLocalizationsExtension = 0;

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final extended = node.onClause?.extendedType.toSource();
    final isLocalizations = extended == _localizationsClass;
    if (isLocalizations) _inLocalizationsExtension++;
    super.visitExtensionDeclaration(node);
    if (isLocalizations) _inLocalizationsExtension--;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_inLocalizationsExtension > 0) identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    identifiers.add(node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    identifiers.add(node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  /// A key with placeholders generates a METHOD, not a getter, so
  /// `l10n.listVideoCount(n)` is a [MethodInvocation] and never reaches
  /// [visitPropertyAccess]. Omitting this reports every parameterized key in
  /// the app as orphaned (316 of them).
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null) identifiers.add(node.methodName.name);
    super.visitMethodInvocation(node);
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
  // lib/ ONLY, deliberately. A test cannot make a key rendered, and taking
  // test references as evidence hid 9 product-orphans — four of them held up
  // by a `findsNothing` assertion, which proves the string is NOT on screen.
  //
  // mobile/packages/ is out of scope for a stronger reason than judgement:
  // AppLocalizations lives in the app, no package depends on package:openvine,
  // and check_package_flutter_boundary.sh keeps it that way — so a package
  // CANNOT reference an ARB key. Scanning it would only add name collisions.
  //
  // Pass roots explicitly to widen the scan.
  final scanRoots = positional.length > 1
      ? positional.sublist(1)
      : const ['lib'];

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
