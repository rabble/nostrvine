// ABOUTME: Shared readers for the iOS sources the static contract tests pin.
// ABOUTME: Scopes assertions to one declaration so they cannot match elsewhere.

import 'dart:io';

/// Reads an iOS source file, from the package root or the workspace root.
///
/// Which one applies depends on where `flutter test` was invoked, so both
/// candidates are tried before giving up.
///
/// Throws a [StateError] naming [fileName] when neither path exists, rather
/// than the bare `No element` a plain `firstWhere` would raise.
String readNativeSource(String fileName) {
  final candidates = [
    File('ios/Classes/$fileName'),
    File('packages/divine_camera/ios/Classes/$fileName'),
  ];
  final file = candidates.firstWhere(
    (file) => file.existsSync(),
    orElse: () => throw StateError(
      'No iOS source "$fileName" at '
      '${candidates.map((file) => file.path).join(' or ')}.',
    ),
  );

  return file.readAsStringSync();
}

/// Returns the Swift declaration starting at [signature] up to its closing
/// brace, so an assertion cannot match an identical line elsewhere in the
/// file, nor a line that sits outside the scope being asserted on.
String declarationAt(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('No declaration starting with "$signature".');
  }

  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces after "$signature".');
}
