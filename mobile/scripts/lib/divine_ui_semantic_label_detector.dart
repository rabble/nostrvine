// ABOUTME: Finds app call sites that rely on English semantic-label defaults
// ABOUTME: exposed by public divine_ui widgets (#7901).
//
// Usage (from mobile/):
//   dart run scripts/lib/divine_ui_semantic_label_detector.dart lib [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              print one line per omitted label
//
// Output (default): `relpath<TAB>count`, one line per file with omissions.
//
// divine_ui deliberately has no dependency on the app's generated
// localizations. Its public widgets therefore carry English fallbacks and let
// the app pass localized strings. That is a useful package boundary, but a
// caller can silently forget a label. This detector freezes that caller debt
// without making conditionally meaningful parameters required everywhere.
//
// A label counts only when its control can render. An omitted trigger uses the
// API's false/null default and does not count; an explicit `false` or `null`
// also does not count. Any other expression is conservatively treated as
// potentially rendering the control.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Thrown when a scanned file cannot be parsed.
class DetectorParseException implements Exception {
  const DetectorParseException(this.message);

  final String message;

  @override
  String toString() => 'DetectorParseException: $message';
}

/// One semantic-label argument required whenever [triggerArgument] can render.
class SemanticLabelRule {
  const SemanticLabelRule({
    required this.api,
    required this.triggerArgument,
    required this.labelArguments,
  });

  final String api;
  final String triggerArgument;
  final List<String> labelArguments;
}

const semanticLabelRules = <SemanticLabelRule>[
  SemanticLabelRule(
    api: 'DivineAuthTextField',
    triggerArgument: 'obscureText',
    labelArguments: ['showPasswordSemanticLabel', 'hidePasswordSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'VineBottomSheet',
    triggerArgument: 'onComplete',
    labelArguments: ['closeSemanticLabel', 'completeSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'VineBottomSheet.show',
    triggerArgument: 'onComplete',
    labelArguments: ['closeSemanticLabel', 'completeSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'DiVineAppBar',
    triggerArgument: 'leadingIcon',
    labelArguments: ['leadingActionSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'DiVineAppBarLeading',
    triggerArgument: 'leadingIcon',
    labelArguments: ['leadingActionSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'DivineSnackbarContainer',
    triggerArgument: 'onDismissPressed',
    labelArguments: ['dismissSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'DivineSnackbarContainer.snackBar',
    triggerArgument: 'onDismissPressed',
    labelArguments: ['dismissSemanticLabel'],
  ),
];

/// One omitted localized semantic label at an app call site.
class SemanticLabelOmission {
  const SemanticLabelOmission({
    required this.path,
    required this.line,
    required this.api,
    required this.argument,
  });

  final String path;
  final int line;
  final String api;
  final String argument;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._lineInfo, this._path);

  final LineInfo _lineInfo;
  final String _path;
  final List<SemanticLabelOmission> omissions = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(
      node.constructorName.type.name.lexeme,
      node.argumentList,
      node.offset,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final targetName = _lastIdentifierName(node.target);
    final api = targetName == null ? methodName : '$targetName.$methodName';

    // An unresolved syntactic parse represents ordinary constructor calls as
    // MethodInvocation. Import-prefixed constructors look like
    // `ui.DivineAuthTextField`, but the API name remains the method name.
    final normalizedApi = semanticLabelRules.any((rule) => rule.api == api)
        ? api
        : methodName;
    _check(normalizedApi, node.argumentList, node.offset);
    super.visitMethodInvocation(node);
  }

  void _check(String api, ArgumentList arguments, int offset) {
    final matchingRules = semanticLabelRules.where((rule) => rule.api == api);
    if (matchingRules.isEmpty) return;

    final named = <String, Expression>{};
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression) {
        named[argument.name.label.name] = argument.expression;
      }
    }

    for (final rule in matchingRules) {
      final trigger = named[rule.triggerArgument];
      if (!_canRender(trigger)) continue;
      for (final label in rule.labelArguments) {
        if (named.containsKey(label)) continue;
        omissions.add(
          SemanticLabelOmission(
            path: _path,
            line: _lineInfo.getLocation(offset).lineNumber,
            api: api,
            argument: label,
          ),
        );
      }
    }
  }
}

bool _canRender(Expression? trigger) {
  if (trigger == null || trigger is NullLiteral) return false;
  return trigger is! BooleanLiteral || trigger.value;
}

String? _lastIdentifierName(Expression? expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    _ => null,
  };
}

/// Finds all relevant semantic-label omissions under [root].
List<SemanticLabelOmission> findSemanticLabelOmissions(
  Directory root, {
  String pathPrefix = '',
}) {
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) =>
                !file.path.contains('/.dart_tool/') &&
                !file.path.contains('/build/') &&
                !file.path.endsWith('.g.dart') &&
                !file.path.endsWith('.freezed.dart') &&
                !file.path.endsWith('.gr.dart') &&
                !file.path.endsWith('.mocks.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final omissions = <SemanticLabelOmission>[];
  for (final file in files) {
    final ParseStringResult parsed;
    try {
      parsed = parseFile(
        path: file.absolute.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
    } on Object catch (error) {
      throw DetectorParseException('could not parse ${file.path}: $error');
    }

    var relativePath = file.path;
    if (pathPrefix.isNotEmpty && relativePath.startsWith(pathPrefix)) {
      relativePath = relativePath.substring(pathPrefix.length);
    }
    relativePath = relativePath.replaceFirst(RegExp('^/'), '');

    final visitor = _Visitor(parsed.lineInfo, relativePath);
    parsed.unit.visitChildren(visitor);
    omissions.addAll(visitor.omissions);
  }

  omissions.sort((a, b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    final lineOrder = a.line.compareTo(b.line);
    if (lineOrder != 0) return lineOrder;
    return a.argument.compareTo(b.argument);
  });
  return omissions;
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln(
      'usage: divine_ui_semantic_label_detector.dart <dir> [--detail]',
    );
    exit(64);
  }

  final root = Directory(arguments.first);
  if (!root.existsSync()) {
    stderr.writeln('no such directory: ${arguments.first}');
    exit(66);
  }

  var pathPrefix = '';
  final prefixIndex = arguments.indexOf('--path-prefix');
  if (prefixIndex != -1 && prefixIndex + 1 < arguments.length) {
    pathPrefix = arguments[prefixIndex + 1];
  }

  final List<SemanticLabelOmission> omissions;
  try {
    omissions = findSemanticLabelOmissions(root, pathPrefix: pathPrefix);
  } on DetectorParseException catch (error) {
    stderr.writeln('FATAL: ${error.message}');
    exit(65);
  }

  if (arguments.contains('--detail')) {
    for (final omission in omissions) {
      stdout.writeln(
        '${omission.path}:${omission.line}\t${omission.api}'
        '\tmissing ${omission.argument}',
      );
    }
    return;
  }

  final counts = <String, int>{};
  for (final omission in omissions) {
    counts.update(omission.path, (count) => count + 1, ifAbsent: () => 1);
  }
  for (final entry in counts.entries) {
    stdout.writeln('${entry.key}\t${entry.value}');
  }
}
